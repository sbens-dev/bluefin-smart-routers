#!/usr/bin/env zsh
# ==============================================================================
# smart-pm.zsh — Unified Package Manager Router for Zsh (Ultimate+ Edition)
# ==============================================================================
# Features (19 total):
#   1.  Routes npm/npx/yarn/bun to the correct PM based on project lockfile.
#   2.  Global installs always go to pnpm (configurable).
#   3.  Blocks npm inside pnpm/yarn/bun projects (protective mode).
#   4.  Full logging of every routing decision to a file.
#   5.  Corepack integration for automatic pnpm version switching.
#   6.  Usage statistics tracking (per-routing counters).
#   7.  Warns when installing an already-present package.
#   8.  Auto-approves trusted packages for pnpm build scripts.
#   9.  Desktop notifications on each routing decision.
#  10.  Export statistics to CSV/JSON/MD.
#  11.  Dry-run mode (persisted across sessions).
#  12.  Unified config file (~/.config/smart-pm/config).
#  13.  Audio beep on block/error events (per-event sounds).
#  14.  Interactive TUI for stats.
#  15.  Git-based config sync across devices.
#  16.  Time-saved tracking (vs npm equivalent).
#  17.  node_modules size comparison (pnpm vs npm).
#  18.  State persistence across shell sessions.
#  19.  Escape hatches: npm-real, npx-real, yarn-real, bun-real.
# ==============================================================================

# ==============================================================================
# Paths
# ==============================================================================
: ${SMART_PM_CONFIG_DIR:=$HOME/.config/smart-pm}
: ${SMART_PM_CONFIG_FILE:=$SMART_PM_CONFIG_DIR/config}
: ${SMART_PM_STATE_FILE:=$HOME/.cache/smart-pm-state}
: ${SMART_PM_LOG_FILE:=$HOME/.cache/smart-pm.log}
: ${SMART_PM_STATS_FILE:=$HOME/.cache/smart-pm-stats}
: ${SMART_PM_TIME_FILE:=$HOME/.cache/smart-pm-time}
: ${SMART_PM_TRUSTED_FILE:=$SMART_PM_CONFIG_DIR/trusted.txt}

mkdir -p "$SMART_PM_CONFIG_DIR" "${SMART_PM_LOG_FILE:h}" "${SMART_PM_STATS_FILE:h}" "${SMART_PM_TIME_FILE:h}" 2>/dev/null

# ==============================================================================
# Defaults
# ==============================================================================
: ${SMART_PM_DEFAULT:=pnpm}
: ${SMART_PM_GLOBAL_PM:=pnpm}
: ${SMART_PM_STRICT:=0}
: ${SMART_PM_PROTECT:=1}
: ${SMART_PM_VERBOSE:=1}
: ${SMART_PM_LOG:=1}
: ${SMART_PM_COREPACK:=1}
: ${SMART_PM_COREPACK_PM:=pnpm}
: ${SMART_PM_STATS:=1}
: ${SMART_PM_WARN_INSTALLED:=1}
: ${SMART_PM_AUTO_APPROVE:=1}
: ${SMART_PM_NOTIFY:=1}
: ${SMART_PM_NOTIFY_LEVEL:=route}
: ${SMART_PM_DRY_RUN:=0}
: ${SMART_PM_BEEP:=1}
: ${SMART_PM_BEEP_CMD:=auto}
: ${SMART_PM_BEEP_ROUTE:=1}
: ${SMART_PM_BEEP_BLOCK:=1}
: ${SMART_PM_BEEP_ERROR:=1}
: ${SMART_PM_TRACK_TIME:=1}
: ${SMART_PM_TIME_MULTIPLIER:=2.5}     # npm is assumed 2.5x slower than pnpm
: ${SMART_PM_SYNC_REMOTE:=}            # e.g. git@github.com:user/dotfiles.git
: ${SMART_PM_SYNC_BRANCH:=main}

# ==============================================================================
# Config file loader
# ==============================================================================
_smart_pm_load_config() {
    [[ -f "$SMART_PM_CONFIG_FILE" ]] || return 0
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        line="${line#export }"
        local key="${line%%=*}"
        local val="${line#*=}"
        val="${val%\"}"; val="${val#\"}"
        val="${val%\'}"; val="${val#\'}"
        val="${val//\$HOME/$HOME}"
        [[ "$key" == SMART_PM_* ]] && typeset -gx "$key=$val"
    done < "$SMART_PM_CONFIG_FILE"
}

# ==============================================================================
# State persistence
# ==============================================================================
_smart_pm_state_load() {
    [[ -f "$SMART_PM_STATE_FILE" ]] || return 0
    while IFS='=' read -r k v; do
        [[ -z "$k" ]] && continue
        case "$k" in
            DRY_RUN) SMART_PM_DRY_RUN="$v" ;;
            VERBOSE) SMART_PM_VERBOSE="$v" ;;
            NOTIFY)  SMART_PM_NOTIFY="$v" ;;
            BEEP)    SMART_PM_BEEP="$v" ;;
            STRICT)  SMART_PM_STRICT="$v" ;;
            PROTECT) SMART_PM_PROTECT="$v" ;;
        esac
    done < "$SMART_PM_STATE_FILE"
}

_smart_pm_state_save() {
    mkdir -p "${SMART_PM_STATE_FILE:h}" 2>/dev/null
    {
        print "DRY_RUN=$SMART_PM_DRY_RUN"
        print "VERBOSE=$SMART_PM_VERBOSE"
        print "NOTIFY=$SMART_PM_NOTIFY"
        print "BEEP=$SMART_PM_BEEP"
        print "STRICT=$SMART_PM_STRICT"
        print "PROTECT=$SMART_PM_PROTECT"
    } > "$SMART_PM_STATE_FILE"
}

_smart_pm_load_config
_smart_pm_state_load

# ==============================================================================
# Logging
# ==============================================================================
_smart_pm_log() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [pid:$$] $*"
    (( SMART_PM_LOG )) && print -r -- "$msg" >> "$SMART_PM_LOG_FILE" 2>/dev/null
    (( SMART_PM_VERBOSE )) && print -u2 -P "\e[36m[smart-pm]\e[0m $*"
}
_smart_pm_warn() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*"
    (( SMART_PM_LOG )) && print -r -- "$msg" >> "$SMART_PM_LOG_FILE" 2>/dev/null
    print -u2 -P "\e[33m[smart-pm]\e[0m $*"
}
_smart_pm_err() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*"
    (( SMART_PM_LOG )) && print -r -- "$msg" >> "$SMART_PM_LOG_FILE" 2>/dev/null
    print -u2 -P "\e[31m[smart-pm]\e[0m $*"
}
_smart_pm_ok() { (( SMART_PM_VERBOSE )) && print -u2 -P "\e[32m[smart-pm]\e[0m $*"; }

# ==============================================================================
# Per-event audio
# ==============================================================================
_smart_pm_play_sound() {
    local kind="$1"   # route | block | error
    local snd=""
    case "$kind" in
        block) snd="/usr/share/sounds/freedesktop/stereo/dialog-error.oga" ;;
        error) snd="/usr/share/sounds/freedesktop/stereo/dialog-warning.oga" ;;
        route) snd="/usr/share/sounds/freedesktop/stereo/message-new-instant.oga" ;;
    esac

    case "$SMART_PM_BEEP_CMD" in
        paplay)
            [[ -f "$snd" ]] && paplay "$snd" 2>/dev/null && return
            ;;
        ffplay)
            if command -v ffplay >/dev/null 2>&1; then
                local freq=800 dur=0.12
                case "$kind" in
                    block) freq=400; dur=0.25 ;;
                    error) freq=600; dur=0.20 ;;
                    route) freq=1000; dur=0.08 ;;
                esac
                ffplay -nodisp -autoexit -loglevel quiet \
                    -f lavfi -i "sine=frequency=$freq:duration=$dur" 2>/dev/null
                return
            fi
            ;;
    esac
    print -n $'\a' > /dev/tty 2>/dev/null
}

_smart_pm_beep() {
    (( SMART_PM_BEEP )) || return 0
    local kind="${1:-route}"
    case "$kind" in
        route) (( SMART_PM_BEEP_ROUTE )) || return 0 ;;
        block) (( SMART_PM_BEEP_BLOCK )) || return 0 ;;
        error) (( SMART_PM_BEEP_ERROR )) || return 0 ;;
    esac
    _smart_pm_play_sound "$kind"
}

# ==============================================================================
# Desktop notifications
# ==============================================================================
_smart_pm_notify() {
    (( SMART_PM_NOTIFY )) || return 0
    command -v notify-send >/dev/null 2>&1 || return 0
    local level="$1"; shift
    local title="$1"; shift
    local body="$*"
    local urgency="normal" icon="utilities-terminal"
    case "$level" in
        block|error) urgency="critical"; icon="dialog-error" ;;
        important)   urgency="normal";   icon="dialog-warning" ;;
        route)       urgency="low";      icon="go-next" ;;
    esac
    case "$SMART_PM_NOTIFY_LEVEL" in
        all)       : ;;
        important) [[ "$level" == "route" ]] && return 0 ;;
        route)     : ;;
    esac
    notify-send -u "$urgency" -i "$icon" -a "smart-pm" -t 3000 "$title" "$body" 2>/dev/null &!
}

_smart_pm_event_block() {
    _smart_pm_notify "block" "$1" "${@:2}"
    _smart_pm_beep block
}
_smart_pm_event_route() {
    _smart_pm_notify "route" "$1" "${@:2}"
    _smart_pm_beep route
}

# ==============================================================================
# Stats
# ==============================================================================
_smart_pm_stat_incr() {
    (( SMART_PM_STATS )) || return 0
    local key="$1"
    local file="$SMART_PM_STATS_FILE"
    mkdir -p "${file:h}" 2>/dev/null
    if [[ -f "$file" ]] && grep -qF "${key}|" "$file" 2>/dev/null; then
        local cur=$(grep -F "${key}|" "$file" | head -1 | cut -d'|' -f2)
        local new=$((cur + 1))
        awk -F'|' -v OFS='|' -v k="$key" -v n="$new" \
            '$1==k { $2=n } { print }' "$file" > "$file.tmp" \
            && mv "$file.tmp" "$file"
    else
        print -r -- "${key}|1" >> "$file"
    fi
}

smart-pm-stats() {
    local file="$SMART_PM_STATS_FILE"
    if [[ ! -f "$file" ]]; then
        print "📊 No statistics recorded yet."
        return
    fi
    print "╔══════════════════════════════════════════════════════════════╗"
    print "║            smart-pm Usage Statistics                         ║"
    print "╚══════════════════════════════════════════════════════════════╝"
    print ""
    local total=0
    while IFS='|' read -r key val; do
        printf "  %-40s %8d\n" "$key" "$val"
        total=$((total + val))
    done < <(sort -t'|' -k2 -rn "$file")
    print ""
    printf "  %-40s %8d\n" "TOTAL" "$total"
}

smart-pm-stats-reset() { : > "$SMART_PM_STATS_FILE"; print "✅ Statistics reset."; }

smart-pm-stats-export() {
    local fmt="${1:-csv}"
    local file="$SMART_PM_STATS_FILE"
    local out="$HOME/smart-pm-stats-$(date +%Y%m%d_%H%M%S).$fmt"
    [[ ! -f "$file" ]] && { _smart_pm_err "no statistics file found"; return 1; }
    case "$fmt" in
        csv)
            { print "key,count"; while IFS='|' read -r k v; do print "${k},${v}"; done < <(sort -t'|' -k2 -rn "$file"); } > "$out" ;;
        json)
            {
                print "{"
                print '  "generated": "'"$(date -Iseconds)"'",'
                print '  "total": '"$(awk -F'|' '{s+=$2} END {print s+0}' "$file")"','
                print '  "entries": {'
                local first=1
                while IFS='|' read -r k v; do
                    [[ $first -eq 0 ]] && print ","
                    first=0
                    local kk="${k//\\/\\\\}"; kk="${kk//\"/\\\"}"
                    print -n '    "'"$kk"'": '"$v"
                done < <(sort -t'|' -k2 -rn "$file")
                print ""
                print "  }"
                print "}"
            } > "$out" ;;
        md|markdown)
            {
                print "# smart-pm Usage Statistics"; print ""
                print "Generated: $(date)"; print ""
                print "| Key | Count |"; print "|---|---|"
                while IFS='|' read -r k v; do print "| \`$k\` | $v |"; done < <(sort -t'|' -k2 -rn "$file")
            } > "$out" ;;
        *) _smart_pm_err "unsupported format: $fmt (use csv, json, or md)"; return 1 ;;
    esac
    _smart_pm_ok "exported to: $out"
    print "$out"
}

smart-pm-stats-tui() {
    local file="$SMART_PM_STATS_FILE"
    [[ ! -f "$file" ]] && { print "📊 No statistics recorded yet."; return 1; }
    local report
    report=$(
        print "smart-pm Usage Statistics"
        print "Generated: $(date)"
        print ""
        print "Total events: $(awk -F'|' '{s+=$2} END {print s+0}' "$file")"
        print ""
        print "=== Breakdown ==="
        print ""
        while IFS='|' read -r k v; do printf "%-40s %8d\n" "$k" "$v"; done < <(sort -t'|' -k2 -rn "$file")
    )
    if command -v whiptail >/dev/null 2>&1; then
        whiptail --title "smart-pm Statistics" --scrolltext --msgbox "$report" 30 90
    elif command -v dialog >/dev/null 2>&1; then
        dialog --title "smart-pm Statistics" --scrollbar --msgbox "$report" 30 90
    elif command -v fzf >/dev/null 2>&1; then
        print -r -- "$report" | fzf --header "smart-pm Statistics (ESC to exit)" --layout=reverse --no-sort --no-info --border --prompt "» " >/dev/null
    else
        print -r -- "$report" | less -R
    fi
}

# ==============================================================================
# Time tracking & savings
# ==============================================================================
_smart_pm_track_time() {
    (( SMART_PM_TRACK_TIME )) || return 0
    local elapsed="$1"; shift
    local pm="$1"; shift
    local cmd="$*"
    mkdir -p "${SMART_PM_TIME_FILE:h}" 2>/dev/null
    print -r -- "$(date +%s)|${pm}|${elapsed}|${cmd}" >> "$SMART_PM_TIME_FILE"
}

smart-pm-time-saved() {
    local file="$SMART_PM_TIME_FILE"
    if [[ ! -f "$file" ]]; then
        print "⏱️  No time-tracking data yet."
        return
    fi
    local total_seconds=0
    local count=0
    while IFS='|' read -r ts pm elapsed cmd; do
        [[ -z "$elapsed" ]] && continue
        # only count pnpm operations (where savings happen)
        [[ "$pm" != "pnpm" ]] && continue
        total_seconds=$((total_seconds + $(printf "%.0f" "$elapsed")))
        count=$((count + 1))
    done < "$file"

    if (( count == 0 )); then
        print "⏱️  No pnpm operations recorded yet."
        return
    fi

    local saved_seconds=$(awk -v t="$total_seconds" -v m="$SMART_PM_TIME_MULTIPLIER" 'BEGIN{printf "%.0f", t*(m-1)}')
    local saved_h=$((saved_seconds / 3600))
    local saved_m=$(((saved_seconds % 3600) / 60))
    local saved_s=$((saved_seconds % 60))
    local total_h=$((total_seconds / 3600))
    local total_m=$(((total_seconds % 3600) / 60))
    local total_s=$((total_seconds % 60))

    print "╔══════════════════════════════════════════════════════════════╗"
    print "║               smart-pm Time-Saved Report                     ║"
    print "╚══════════════════════════════════════════════════════════════╝"
    print ""
    print "  Operations tracked:      $count"
    print "  Total time in pnpm:      ${total_h}h ${total_m}m ${total_s}s"
    print "  Assumed npm multiplier:  ${SMART_PM_TIME_MULTIPLIER}x"
    print "  ─────────────────────────────────────────"
    print "  🎉 Estimated time saved: ${saved_h}h ${saved_m}m ${saved_s}s"
    print ""
    print "  (Compared against running the same ops with npm)"
}

smart-pm-time-reset() { : > "$SMART_PM_TIME_FILE"; print "✅ Time tracking reset."; }

# ==============================================================================
# node_modules size comparison
# ==============================================================================
smart-pm-size() {
    local dir="${1:-$PWD}"
    local nm="$dir/node_modules"
    if [[ ! -d "$nm" ]]; then
        _smart_pm_err "no node_modules found in $dir"
        return 1
    fi

    print "📦 Analyzing node_modules in: $dir"
    print ""

    # Actual disk usage (pnpm hardlinks → smaller)
    local actual_size=$(du -sh "$nm" 2>/dev/null | cut -f1)
    # Apparent size (sum of file sizes ignoring hardlinks — same as npm would store)
    local apparent_size=$(du -sh --apparent-size "$nm" 2>/dev/null | cut -f1)
    # File count
    local file_count=$(find "$nm" -type f 2>/dev/null | wc -l)
    local symlink_count=$(find "$nm" -type l 2>/dev/null | wc -l)

    # Numeric sizes in bytes for calculation
    local actual_bytes=$(du -sb "$nm" 2>/dev/null | cut -f1)
    local apparent_bytes=$(du -sb --apparent-size "$nm" 2>/dev/null | cut -f1)
    [[ -z "$actual_bytes" ]] && actual_bytes=0
    [[ -z "$apparent_bytes" ]] && apparent_bytes=0
    local saved_bytes=$((apparent_bytes - actual_bytes))
    local saved_pct=0
    (( apparent_bytes > 0 )) && saved_pct=$((saved_bytes * 100 / apparent_bytes))

    print "╔══════════════════════════════════════════════════════════════╗"
    print "║           smart-pm node_modules Size Comparison              ║"
    print "╚══════════════════════════════════════════════════════════════╝"
    print ""
    print "  Files:                   $file_count"
    print "  Symlinks:                $symlink_count"
    print ""
    print "  Actual disk usage:       $actual_size   (pnpm with hardlinks)"
    print "  Apparent size:           $apparent_size   (npm equivalent)"
    print "  ─────────────────────────────────────────"
    print "  💾 Space saved by pnpm:  $(numfmt --to=iec --suffix=B "$saved_bytes" 2>/dev/null || echo "${saved_bytes}B")  (${saved_pct}%)"
    print ""
    print "  ℹ️  The 'apparent size' is what the same tree would occupy"
    print "     if stored without pnpm's hardlink optimization."
}

# ==============================================================================
# Git-based config sync
# ==============================================================================
_smart_pm_sync_ensure_git() {
    if ! command -v git >/dev/null 2>&1; then
        _smart_pm_err "git is not installed"
        return 1
    fi
    return 0
}

smart-pm-sync-init() {
    _smart_pm_sync_ensure_git || return 1
    local remote="$1"
    if [[ -z "$remote" ]]; then
        _smart_pm_err "usage: smart-pm-sync-init <git-remote-url>"
        print "  Example: smart-pm-sync-init git@github.com:me/dotfiles.git"
        return 1
    fi
    if [[ -d "$SMART_PM_CONFIG_DIR/.git" ]]; then
        _smart_pm_err "already initialized in $SMART_PM_CONFIG_DIR"
        return 1
    fi
    (
        cd "$SMART_PM_CONFIG_DIR" || exit 1
        git init -q
        git config user.name "$(git config --global user.name || echo 'smart-pm')"
        git config user.email "$(git config --global user.email || echo 'smart-pm@local')"
        cat > .gitignore <<'EOF'
config.local
state
trusted.local.txt
*.bak
EOF
        git add -A
        git commit -q -m "Initial smart-pm config" 2>/dev/null
        git branch -M "$SMART_PM_SYNC_BRANCH"
        git remote add origin "$remote"
    )
    _smart_pm_ok "git repo initialized in $SMART_PM_CONFIG_DIR"
    print "  Remote: $remote"
    print "  Next:  smart-pm-sync-push"
}

smart-pm-sync-push() {
    _smart_pm_sync_ensure_git || return 1
    if [[ ! -d "$SMART_PM_CONFIG_DIR/.git" ]]; then
        _smart_pm_err "not a git repo — run 'smart-pm-sync-init <remote>' first"
        return 1
    fi
    (
        cd "$SMART_PM_CONFIG_DIR" || exit 1
        git add -A
        local msg="sync: $(date '+%Y-%m-%d %H:%M:%S') on $(hostname)"
        git commit -q -m "$msg" 2>/dev/null
        git push -q -u origin "$SMART_PM_SYNC_BRANCH"
    )
    _smart_pm_ok "pushed to $SMART_PM_SYNC_BRANCH"
}

smart-pm-sync-pull() {
    _smart_pm_sync_ensure_git || return 1
    if [[ ! -d "$SMART_PM_CONFIG_DIR/.git" ]]; then
        _smart_pm_err "not a git repo — run 'smart-pm-sync-init <remote>' first"
        return 1
    fi
    (
        cd "$SMART_PM_CONFIG_DIR" || exit 1
        git pull -q origin "$SMART_PM_SYNC_BRANCH"
    )
    _smart_pm_ok "pulled from $SMART_PM_SYNC_BRANCH"
    smart-pm-reload
}

smart-pm-sync-status() {
    _smart_pm_sync_ensure_git || return 1
    if [[ ! -d "$SMART_PM_CONFIG_DIR/.git" ]]; then
        print "⚠️  Config dir is not a git repo. Run 'smart-pm-sync-init <remote>'."
        return 0
    fi
    (
        cd "$SMART_PM_CONFIG_DIR" || exit 1
        print "📂 Config dir:    $SMART_PM_CONFIG_DIR"
        print "🌿 Branch:        $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
        print "🔗 Remote:        $(git remote get-url origin 2>/dev/null || echo '(none)')"
        print "📍 Last commit:   $(git log -1 --format='%h %s' 2>/dev/null)"
        print ""
        print "Status:"
        git -c color.status=always status -sb
    )
}

smart-pm-sync-edit-remote() {
    local new_remote="$1"
    [[ -z "$new_remote" ]] && { _smart_pm_err "usage: smart-pm-sync-edit-remote <url>"; return 1; }
    (
        cd "$SMART_PM_CONFIG_DIR" || exit 1
        git remote set-url origin "$new_remote"
    )
    _smart_pm_ok "remote updated to: $new_remote"
}

# ==============================================================================
# Detection helpers
# ==============================================================================
_smart_pm_detect() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        [[ -f "$dir/pnpm-lock.yaml" ]] && { print pnpm; return }
        [[ -f "$dir/bun.lockb" || -f "$dir/bun.lock" ]] && { print bun; return }
        [[ -f "$dir/yarn.lock" ]] && { print yarn; return }
        [[ -f "$dir/package-lock.json" ]] && { print npm; return }
        [[ -f "$dir/package.json" ]] && { print "$SMART_PM_DEFAULT"; return }
        dir="${dir:h}"
    done
    print ""
}

_smart_pm_is_global() {
    local a; for a in "$@"; do [[ "$a" == "-g" || "$a" == "--global" ]] && return 0; done
    return 1
}
_smart_pm_has() { command -v "$1" >/dev/null 2>&1; }

_smart_pm_corepack() {
    (( SMART_PM_COREPACK )) || return 0
    _smart_pm_has corepack || return 0
    _smart_pm_has "$SMART_PM_COREPACK_PM" && return 0
    _smart_pm_log "activating $SMART_PM_COREPACK_PM via corepack"
    command corepack prepare "$SMART_PM_COREPACK_PM@latest" --activate 2>/dev/null \
        || command corepack enable "$SMART_PM_COREPACK_PM" 2>/dev/null
}

# ==============================================================================
# Dry-run + time-tracking executor
# ==============================================================================
_smart_pm_exec() {
    if (( SMART_PM_DRY_RUN )); then
        print -u2 -P "\e[35m[smart-pm:DRY-RUN]\e[0m would execute: $*"
        _smart_pm_notify "route" "Dry-run" "would execute: $*"
        return 0
    fi

    # Detect target PM from first arg for time tracking
    local target_pm="$1"
    [[ "$target_pm" == "command" ]] && target_pm="$2"

    if (( SMART_PM_TRACK_TIME )) && [[ "$target_pm" == "pnpm" ]]; then
        local start=$(date +%s.%N)
        "$@"
        local rc=$?
        local end=$(date +%s.%N)
        local elapsed=$(awk -v s="$start" -v e="$end" 'BEGIN{printf "%.3f", e-s}')
        _smart_pm_track_time "$elapsed" "$target_pm" "$*"
        return $rc
    fi
    "$@"
}

# ==============================================================================
# Installed-package check
# ==============================================================================
_smart_pm_extract_packages() {
    local a
    for a in "$@"; do
        [[ "$a" == -* ]] && continue
        [[ "$a" == "." || "$a" == "./"* || "$a" == "../"* ]] && continue
        [[ "$a" == /* ]] && continue
        [[ -f "$a" || -d "$a" ]] && continue
        print -r -- "$a"
    done
}

_smart_pm_is_installed() {
    local pkg="$1"
    pkg="${pkg#npm:}"
    if [[ "$pkg" == @*/*@* ]]; then
        pkg="${pkg%@*}"
    elif [[ "$pkg" != @* && "$pkg" == *@* ]]; then
        pkg="${pkg%%@*}"
    fi
    [[ -z "$pkg" ]] && return 1
    if [[ -f "package.json" ]] && grep -qF "\"${pkg}\"" "package.json"; then return 0; fi
    [[ -d "node_modules/$pkg" ]] && return 0
    return 1
}

_smart_pm_check_installed_packages() {
    (( SMART_PM_WARN_INSTALLED )) || return 0
    local sub="$1"; shift
    [[ "$sub" != "add" && "$sub" != "install" && "$sub" != "i" ]] && return 0
    local -a pkgs
    while IFS= read -r p; do [[ -n "$p" ]] && pkgs+=("$p"); done < <(_smart_pm_extract_packages "$@")
    (( ${#pkgs[@]} == 0 )) && return 0
    local -a already
    for p in "${pkgs[@]}"; do _smart_pm_is_installed "$p" && already+=("$p"); done
    (( ${#already[@]} == 0 )) && return 0
    _smart_pm_warn "already installed: ${(j:, :)already}"
    _smart_pm_notify "important" "Package already installed" "${(j:, :)already}"
    if [[ -t 0 ]]; then
        print -u2 -P "\e[33m[smart-pm]\e[0m Continue anyway? [y/N] "
        local ans; read -r ans
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            _smart_pm_stat_incr "aborted:already-installed"
            _smart_pm_log "aborted install — packages already present"
            return 1
        fi
    else
        _smart_pm_log "non-interactive: auto-confirming install of already-present packages"
    fi
    _smart_pm_stat_incr "confirmed:reinstall"
    return 0
}

# ==============================================================================
# Trusted packages
# ==============================================================================
_smart_pm_ensure_trusted_defaults() {
    local file="$SMART_PM_TRUSTED_FILE"
    [[ -f "$file" ]] && return
    mkdir -p "${file:h}" 2>/dev/null
    cat > "$file" <<'EOF'
# smart-pm trusted packages — build scripts auto-approved with pnpm
@deepseek-ai/dsh-subprocess-local
@google/genai
@img/sharp-libvips-linux-x64
esbuild
koffi
node-pty
protobufjs
sharp
EOF
}

_smart_pm_approve_trusted() {
    (( SMART_PM_AUTO_APPROVE )) || return 0
    _smart_pm_has pnpm || return 0
    _smart_pm_ensure_trusted_defaults
    local file="$SMART_PM_TRUSTED_FILE"
    [[ -f "$file" ]] || return 0
    local npmrc="$HOME/.npmrc"
    local -a missing
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        if ! grep -qF "only-built-dependencies[]=$line" "$npmrc" 2>/dev/null; then
            missing+=("$line")
        fi
    done < "$file"
    (( ${#missing[@]} == 0 )) && return 0
    [[ -f "$npmrc" ]] && cp "$npmrc" "$npmrc.smart-pm.bak" 2>/dev/null
    {
        print ""; print "# smart-pm: only-built-dependencies (auto-added)"
        for pkg in "${missing[@]}"; do print "only-built-dependencies[]=$pkg"; done
    } >> "$npmrc"
    _smart_pm_log "approved ${#missing[@]} trusted package(s) for build"
    _smart_pm_stat_incr "approved:build-scripts"
}

smart-pm-trusted() {
    _smart_pm_ensure_trusted_defaults
    print "📋 Trusted packages file: $SMART_PM_TRUSTED_FILE"; print ""
    [[ -f "$SMART_PM_TRUSTED_FILE" ]] && grep -vE '^\s*(#|$)' "$SMART_PM_TRUSTED_FILE" | while read -r p; do print "  • $p"; done
}
smart-pm-trusted-add() {
    local pkg="$1"
    [[ -z "$pkg" ]] && { _smart_pm_err "usage: smart-pm-trusted-add <package>"; return 1; }
    _smart_pm_ensure_trusted_defaults
    echo "$pkg" >> "$SMART_PM_TRUSTED_FILE"
    _smart_pm_ok "added to trusted: $pkg"
}
smart-pm-trusted-edit() { _smart_pm_ensure_trusted_defaults; "${EDITOR:-nano}" "$SMART_PM_TRUSTED_FILE"; }

# ==============================================================================
# Core router
# ==============================================================================
_smart_pm_run() {
    local bin="$1"; shift
    local -a args=("$@")
    local pm=$(_smart_pm_detect)
    local sub="${args[1]:-}"
    local display="${_SMART_PM_ORIGIN:-$bin}"

    # Global
    if _smart_pm_is_global "${args[@]}"; then
        _smart_pm_corepack
        if ! _smart_pm_has "$SMART_PM_GLOBAL_PM"; then
            _smart_pm_err "global PM '$SMART_PM_GLOBAL_PM' not found; falling back to $bin"
            _smart_pm_stat_incr "fallback:global→$bin"
            _smart_pm_event_block "Fallback to $bin" "global PM '$SMART_PM_GLOBAL_PM' missing"
            _smart_pm_exec command "$bin" "${args[@]}"; return $?
        fi
        local -a _gargs=("${args[@]}") ; case "${_gargs[1]}" in install|i) _gargs[1]="add" ;; uninstall|un|remove|rm) _gargs[1]="remove" ;; esac
        _smart_pm_stat_incr "global→$SMART_PM_GLOBAL_PM"
        _smart_pm_log "global op → $SMART_PM_GLOBAL_PM ${_gargs[*]}"
        _smart_pm_event_route "Global install" "→ $SMART_PM_GLOBAL_PM ${_gargs[*]}"
        _smart_pm_approve_trusted
        _smart_pm_exec command "$SMART_PM_GLOBAL_PM" "${_gargs[@]}"
        return $?
    fi

    # No project
    if [[ -z "$pm" ]]; then
        case "$sub" in
            install|i|add|uninstall|un|remove|rm|run|test|t|exec|init|ci|ls|list|outdated|update|up|link)
                _smart_pm_corepack
                if [[ "$sub" == "add" || "$sub" == "install" || "$sub" == "i" ]]; then
                    _smart_pm_check_installed_packages "$sub" "${args[@]:1}" || return 1
                fi
                _smart_pm_stat_incr "nocontext→$SMART_PM_DEFAULT"
                _smart_pm_log "no lockfile → $SMART_PM_DEFAULT ${args[*]}"
                _smart_pm_event_route "No project" "→ $SMART_PM_DEFAULT ${args[*]}"
                _smart_pm_approve_trusted
                _smart_pm_exec command "$SMART_PM_DEFAULT" "${args[@]}"; return $?
                ;;
            *)
                _smart_pm_stat_incr "passthrough→$bin"
                _smart_pm_exec command "$bin" "${args[@]}"; return $?
                ;;
        esac
    fi

    # Project is npm
    if [[ "$pm" == "npm" ]]; then
        if (( SMART_PM_PROTECT )); then
            _smart_pm_err "refusing $bin inside a project using npm (use '$bin-real' to force)"
            _smart_pm_stat_incr "blocked:$bin-in-npm-project"
            _smart_pm_event_block "Blocked $bin" "project uses npm; use '$bin-real'"
            return 1
        fi
        _smart_pm_stat_incr "passthrough:$bin"
        _smart_pm_exec command "$bin" "${args[@]}"; return $?
    fi

    # Strict
    if (( SMART_PM_STRICT )) && [[ "$bin" == "npm" ]]; then
        _smart_pm_err "npm is blocked (SMART_PM_STRICT=1). Use 'npm-real'."
        _smart_pm_stat_incr "blocked:strict-npm"
        _smart_pm_event_block "npm blocked" "SMART_PM_STRICT=1"
        return 1
    fi

    # Right binary
    if [[ "$pm" == "$bin" ]]; then
        _smart_pm_stat_incr "passthrough:$bin"
        _smart_pm_exec command "$bin" "${args[@]}"; return $?
    fi

    # Corepack fallback
    if ! _smart_pm_has "$pm"; then
        _smart_pm_corepack
        if ! _smart_pm_has "$pm"; then
            _smart_pm_err "target PM '$pm' not available; running '$bin' instead"
            _smart_pm_stat_incr "fallback:$pm→$bin"
            _smart_pm_event_block "Fallback to $bin" "target PM '$pm' unavailable"
            _smart_pm_exec command "$bin" "${args[@]}"; return $?
        fi
    fi

    # Installed check
    if [[ "$sub" == "add" || "$sub" == "install" || "$sub" == "i" ]]; then
        _smart_pm_check_installed_packages "$sub" "${args[@]:1}" || return 1
    fi

    case "$sub" in
        install|i)
            _smart_pm_stat_incr "$display→$pm:install"; _smart_pm_log "$display install → $pm install"
            _smart_pm_event_route "$display → $pm" "install"
            _smart_pm_approve_trusted
            _smart_pm_exec command "$pm" install "${args[@]:1}" ;;
        add)
            _smart_pm_stat_incr "$display→$pm:add"; _smart_pm_log "$display add → $pm add"
            _smart_pm_event_route "$display → $pm" "add ${args[*]:1}"
            _smart_pm_approve_trusted
            _smart_pm_exec command "$pm" add "${args[@]:1}" ;;
        uninstall|un|remove|rm)
            _smart_pm_stat_incr "$display→$pm:remove"; _smart_pm_log "$display remove → $pm remove"
            _smart_pm_event_route "$display → $pm" "remove ${args[*]:1}"
            _smart_pm_exec command "$pm" remove "${args[@]:1}" ;;
        ci)
            case "$pm" in
                pnpm) _smart_pm_stat_incr "$display→pnpm:ci"; _smart_pm_log "$display ci → pnpm install --frozen-lockfile"
                      _smart_pm_event_route "$display → pnpm" "ci"; _smart_pm_exec command pnpm install --frozen-lockfile ;;
                yarn) _smart_pm_stat_incr "$display→yarn:ci"; _smart_pm_log "$display ci → yarn install --immutable"
                      _smart_pm_event_route "$display → yarn" "ci"; _smart_pm_exec command yarn install --immutable ;;
                bun)  _smart_pm_stat_incr "$display→bun:ci";  _smart_pm_log "$display ci → bun install --frozen-lockfile"
                      _smart_pm_event_route "$display → bun" "ci"; _smart_pm_exec command bun install --frozen-lockfile ;;
            esac ;;
        run|test|t|exec|x|dlx)
            _smart_pm_stat_incr "$display→$pm:$sub"; _smart_pm_log "$display $sub → $pm $sub"
            _smart_pm_event_route "$display → $pm" "$sub ${args[*]:1}"
            _smart_pm_exec command "$pm" "${args[@]}" ;;
        *)
            _smart_pm_stat_incr "$display→$pm:other"; _smart_pm_log "$display ${args[*]} → $pm ${args[*]}"
            _smart_pm_event_route "$display → $pm" "${args[*]}"
            _smart_pm_exec command "$pm" "${args[@]}" ;;
    esac
    return $?
}

# ==============================================================================
# Public functions
# ==============================================================================
npm()  { _smart_pm_run npm  "$@"; }
npx()  {
    local pm=$(_smart_pm_detect)
    case "$pm" in
        pnpm)
              if ! _smart_pm_has pnpm; then
                  _smart_pm_stat_incr "npx:passthrough"; _smart_pm_exec command npx "$@"
              else
                  _smart_pm_stat_incr "npx→pnpm:dlx"; _smart_pm_log "npx → pnpm dlx $*"
                  _smart_pm_event_route "npx → pnpm dlx" "$*"; _smart_pm_exec command pnpm dlx "$@"
              fi ;;
        yarn) _smart_pm_stat_incr "npx→yarn:dlx"; _smart_pm_log "npx → yarn dlx $*"
              _smart_pm_event_route "npx → yarn dlx" "$*"; _smart_pm_exec command yarn dlx "$@" ;;
        bun)  _smart_pm_stat_incr "npx→bunx";     _smart_pm_log "npx → bunx $*"
              _smart_pm_event_route "npx → bunx" "$*"; _smart_pm_exec command bunx "$@" ;;
        *)    _smart_pm_stat_incr "npx:passthrough"; _smart_pm_exec command npx "$@" ;;
    esac
}
yarn() {
    local pm=$(_smart_pm_detect)
    if [[ "$pm" == "pnpm" ]]; then
        typeset -g _SMART_PM_ORIGIN="yarn"
        _smart_pm_run npm "$@"
        unset _SMART_PM_ORIGIN
    else
        _smart_pm_stat_incr "yarn:passthrough"; _smart_pm_exec command yarn "$@"
    fi
}
bun() {
    local pm=$(_smart_pm_detect)
    if [[ "$pm" == "pnpm" ]]; then
        typeset -g _SMART_PM_ORIGIN="bun"
        _smart_pm_run npm "$@"
        unset _SMART_PM_ORIGIN
    else
        _smart_pm_stat_incr "bun:passthrough"; _smart_pm_exec command bun "$@"
    fi
}

alias npm-real='command npm'
alias npx-real='command npx'
alias yarn-real='command yarn'
alias bun-real='command bun'

# ==============================================================================
# Utility commands
# ==============================================================================
smart-pm-where() {
    local pm=$(_smart_pm_detect)
    [[ -z "$pm" ]] && print "📍 No project detected. Default PM: $SMART_PM_DEFAULT" \
                    || print "📍 Detected PM for $PWD: $pm"
}

smart-pm-log()     { local n="${1:-20}"; print "📜 Last $n routing decisions ($SMART_PM_LOG_FILE):"; print ""; tail -n "$n" "$SMART_PM_LOG_FILE" 2>/dev/null || print "No log entries yet."; }
smart-pm-log-clear() { : > "$SMART_PM_LOG_FILE"; print "✅ Log cleared."; }

smart-pm-verbose() { if (( SMART_PM_VERBOSE )); then SMART_PM_VERBOSE=0; print "🔇 Verbose: OFF"; else SMART_PM_VERBOSE=1; print "🔊 Verbose: ON"; fi; _smart_pm_state_save; }
smart-pm-notify()  { if (( SMART_PM_NOTIFY )); then SMART_PM_NOTIFY=0; print "🔕 Notifications: OFF"; else SMART_PM_NOTIFY=1; print "🔔 Notifications: ON"; fi; _smart_pm_state_save; }
smart-pm-beep()    { if (( SMART_PM_BEEP )); then SMART_PM_BEEP=0; print "🔇 Beep: OFF"; else SMART_PM_BEEP=1; print "🔊 Beep: ON"; _smart_pm_beep route; fi; _smart_pm_state_save; }
smart-pm-dry-run() { if (( SMART_PM_DRY_RUN )); then SMART_PM_DRY_RUN=0; print "▶️  Dry-run: OFF"; else SMART_PM_DRY_RUN=1; print "🧪 Dry-run: ON"; fi; _smart_pm_state_save; }
smart-pm-strict()  { if (( SMART_PM_STRICT )); then SMART_PM_STRICT=0; print "🟢 Strict: OFF"; else SMART_PM_STRICT=1; print "🔴 Strict: ON"; fi; _smart_pm_state_save; }
smart-pm-protect() { if (( SMART_PM_PROTECT )); then SMART_PM_PROTECT=0; print "🟢 Protect: OFF"; else SMART_PM_PROTECT=1; print "🔴 Protect: ON"; fi; _smart_pm_state_save; }

# ==============================================================================
# Config management
# ==============================================================================
_smart_pm_ensure_config_defaults() {
    [[ -f "$SMART_PM_CONFIG_FILE" ]] && return
    cat > "$SMART_PM_CONFIG_FILE" <<'EOF'
# =============================================================================
# smart-pm Configuration
# After editing, run: smart-pm-reload
# =============================================================================

# Core behavior
SMART_PM_DEFAULT=pnpm
SMART_PM_GLOBAL_PM=pnpm
SMART_PM_STRICT=0
SMART_PM_PROTECT=1

# Output
SMART_PM_VERBOSE=1
SMART_PM_LOG=1
SMART_PM_LOG_FILE=$HOME/.cache/smart-pm.log

# Corepack
SMART_PM_COREPACK=1
SMART_PM_COREPACK_PM=pnpm

# Statistics
SMART_PM_STATS=1
SMART_PM_STATS_FILE=$HOME/.cache/smart-pm-stats

# Safety checks
SMART_PM_WARN_INSTALLED=1
SMART_PM_AUTO_APPROVE=1
SMART_PM_TRUSTED_FILE=$HOME/.config/smart-pm/trusted.txt

# Notifications
SMART_PM_NOTIFY=1
SMART_PM_NOTIFY_LEVEL=route

# Audio (per event)
SMART_PM_BEEP=1
SMART_PM_BEEP_CMD=auto
SMART_PM_BEEP_ROUTE=1
SMART_PM_BEEP_BLOCK=1
SMART_PM_BEEP_ERROR=1

# Time tracking
SMART_PM_TRACK_TIME=1
SMART_PM_TIME_MULTIPLIER=2.5
SMART_PM_TIME_FILE=$HOME/.cache/smart-pm-time

# Git sync
SMART_PM_SYNC_REMOTE=
SMART_PM_SYNC_BRANCH=main

# Dry-run
SMART_PM_DRY_RUN=0
EOF
}

smart-pm-config()   { _smart_pm_ensure_config_defaults; "${EDITOR:-nano}" "$SMART_PM_CONFIG_FILE"; _smart_pm_ok "config saved"; print "Run 'smart-pm-reload' to apply."; }
smart-pm-reload()   { _smart_pm_load_config; _smart_pm_state_load; print "✅ smart-pm config reloaded."; }
smart-pm-state()    { print "🧠 Runtime state ($SMART_PM_STATE_FILE):"; print ""
                      print "  DRY_RUN=$SMART_PM_DRY_RUN"; print "  VERBOSE=$SMART_PM_VERBOSE"
                      print "  NOTIFY=$SMART_PM_NOTIFY"; print "  BEEP=$SMART_PM_BEEP"
                      print "  STRICT=$SMART_PM_STRICT"; print "  PROTECT=$SMART_PM_PROTECT"; }
smart-pm-state-reset() { rm -f "$SMART_PM_STATE_FILE"; print "✅ Runtime state reset. Run 'smart-pm-reload'."; }

smart-pm-status() {
    print "╔══════════════════════════════════════════════════════════════╗"
    print "║                    smart-pm Status                           ║"
    print "╚══════════════════════════════════════════════════════════════╝"
    print ""
    print "Paths:"
    print "  Config:              $SMART_PM_CONFIG_FILE"
    print "  State:               $SMART_PM_STATE_FILE"
    print "  Log:                 $SMART_PM_LOG_FILE"
    print "  Stats:               $SMART_PM_STATS_FILE"
    print "  Time:                $SMART_PM_TIME_FILE"
    print "  Trusted:             $SMART_PM_TRUSTED_FILE"
    print ""
    print "Configuration:"
    print "  Default PM:          $SMART_PM_DEFAULT"
    print "  Global PM:           $SMART_PM_GLOBAL_PM"
    print "  Strict:              $SMART_PM_STRICT"
    print "  Protect:             $SMART_PM_PROTECT"
    print "  Verbose:             $SMART_PM_VERBOSE"
    print "  Log:                 $SMART_PM_LOG"
    print "  Stats:               $SMART_PM_STATS"
    print "  Warn installed:      $SMART_PM_WARN_INSTALLED"
    print "  Auto-approve:        $SMART_PM_AUTO_APPROVE"
    print "  Corepack:            $SMART_PM_COREPACK"
    print "  Notify:              $SMART_PM_NOTIFY ($SMART_PM_NOTIFY_LEVEL)"
    print "  Beep:                $SMART_PM_BEEP (route:$SMART_PM_BEEP_ROUTE block:$SMART_PM_BEEP_BLOCK error:$SMART_PM_BEEP_ERROR)"
    print "  Track time:          $SMART_PM_TRACK_TIME (×$SMART_PM_TIME_MULTIPLIER)"
    print "  Dry-run:             $SMART_PM_DRY_RUN"
    print "  Sync remote:         ${SMART_PM_SYNC_REMOTE:-(not configured)}"
    print ""
    print "Current directory:"; smart-pm-where
    print ""
    print "Commands:"
    print "  ── Diagnostics ──"
    print "    smart-pm-status, smart-pm-where, smart-pm-state"
    print "  ── Config ──"
    print "    smart-pm-config, smart-pm-reload, smart-pm-state-reset"
    print "  ── Stats ──"
    print "    smart-pm-stats, smart-pm-stats-tui, smart-pm-stats-reset"
    print "    smart-pm-stats-export {csv|json|md}"
    print "  ── Time ──"
    print "    smart-pm-time-saved, smart-pm-time-reset"
    print "  ── Size ──"
    print "    smart-pm-size [path]"
    print "  ── Sync ──"
    print "    smart-pm-sync-init <remote>, smart-pm-sync-push"
    print "    smart-pm-sync-pull, smart-pm-sync-status"
    print "  ── Log ──"
    print "    smart-pm-log [n], smart-pm-log-clear"
    print "  ── Trusted ──"
    print "    smart-pm-trusted, smart-pm-trusted-add, smart-pm-trusted-edit"
    print "  ── Toggles ──"
    print "    smart-pm-verbose, smart-pm-notify, smart-pm-beep"
    print "    smart-pm-dry-run, smart-pm-strict, smart-pm-protect"
}

# ==============================================================================
# End of smart-pm.zsh
# ==============================================================================