#!/usr/bin/env zsh
# ==============================================================================
# smart-py.zsh — Unified Python Package Manager Router
# ==============================================================================
# Routes pip/pip3/pipx/poetry/pdm to uv equivalents based on project context.
# Provides logging, stats, dry-run, notifications, and escape hatches.
# ==============================================================================

# ---------- Paths ----------
: ${SMART_PY_CONFIG_DIR:=$HOME/.config/smart-py}
: ${SMART_PY_CONFIG_FILE:=$SMART_PY_CONFIG_DIR/config}
: ${SMART_PY_STATE_FILE:=$HOME/.cache/smart-py-state}
: ${SMART_PY_LOG_FILE:=$HOME/.cache/smart-py.log}
: ${SMART_PY_STATS_FILE:=$HOME/.cache/smart-py-stats}
: ${SMART_PY_TIME_FILE:=$HOME/.cache/smart-py-time}
mkdir -p "$SMART_PY_CONFIG_DIR" "${SMART_PY_LOG_FILE:h}" 2>/dev/null

# ---------- Defaults ----------
: ${SMART_PY_DEFAULT:=uv}
: ${SMART_PY_GLOBAL_PM:=uv-tool}
: ${SMART_PY_STRICT:=0}
: ${SMART_PY_PROTECT:=1}
: ${SMART_PY_VERBOSE:=1}
: ${SMART_PY_LOG:=1}
: ${SMART_PY_STATS:=1}
: ${SMART_PY_NOTIFY:=1}
: ${SMART_PY_NOTIFY_LEVEL:=route}
: ${SMART_PY_DRY_RUN:=0}
: ${SMART_PY_BEEP:=1}
: ${SMART_PY_BEEP_CMD:=auto}
: ${SMART_PY_TRACK_TIME:=1}
: ${SMART_PY_TIME_MULTIPLIER:=10}   # uv is ~10x faster than pip

# ---------- Load config ----------
_smart_py_load_config() {
    [[ -f "$SMART_PY_CONFIG_FILE" ]] || return 0
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        line="${line#export }"
        local key="${line%%=*}"
        local val="${line#*=}"
        val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
        val="${val//\$HOME/$HOME}"
        [[ "$key" == SMART_PY_* ]] && typeset -gx "$key=$val"
    done < "$SMART_PY_CONFIG_FILE"
}

_smart_py_state_load() {
    [[ -f "$SMART_PY_STATE_FILE" ]] || return 0
    while IFS='=' read -r k v; do
        [[ -z "$k" ]] && continue
        case "$k" in
            DRY_RUN) SMART_PY_DRY_RUN="$v" ;;
            VERBOSE) SMART_PY_VERBOSE="$v" ;;
            NOTIFY)  SMART_PY_NOTIFY="$v" ;;
            BEEP)    SMART_PY_BEEP="$v" ;;
            STRICT)  SMART_PY_STRICT="$v" ;;
            PROTECT) SMART_PY_PROTECT="$v" ;;
        esac
    done < "$SMART_PY_STATE_FILE"
}

_smart_py_state_save() {
    mkdir -p "${SMART_PY_STATE_FILE:h}" 2>/dev/null
    {
        print "DRY_RUN=$SMART_PY_DRY_RUN"
        print "VERBOSE=$SMART_PY_VERBOSE"
        print "NOTIFY=$SMART_PY_NOTIFY"
        print "BEEP=$SMART_PY_BEEP"
        print "STRICT=$SMART_PY_STRICT"
        print "PROTECT=$SMART_PY_PROTECT"
    } > "$SMART_PY_STATE_FILE"
}

_smart_py_load_config
_smart_py_state_load

# ---------- Logging ----------
_smart_py_log() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [pid:$$] $*"
    (( SMART_PY_LOG )) && print -r -- "$msg" >> "$SMART_PY_LOG_FILE" 2>/dev/null
    (( SMART_PY_VERBOSE )) && print -u2 -P "\e[36m[smart-py]\e[0m $*"
}
_smart_py_warn() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*"
    (( SMART_PY_LOG )) && print -r -- "$msg" >> "$SMART_PY_LOG_FILE" 2>/dev/null
    print -u2 -P "\e[33m[smart-py]\e[0m $*"
}
_smart_py_err() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*"
    (( SMART_PY_LOG )) && print -r -- "$msg" >> "$SMART_PY_LOG_FILE" 2>/dev/null
    print -u2 -P "\e[31m[smart-py]\e[0m $*"
}
_smart_py_ok() { (( SMART_PY_VERBOSE )) && print -u2 -P "\e[32m[smart-py]\e[0m $*"; }

# ---------- Notifications & beep ----------
_smart_py_beep() {
    (( SMART_PY_BEEP )) || return 0
    case "$SMART_PY_BEEP_CMD" in
        paplay)
            local snd="/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
            [[ -f "$snd" ]] && paplay "$snd" 2>/dev/null && return
            ;;
        ffplay)
            command -v ffplay >/dev/null 2>&1 && \
                ffplay -nodisp -autoexit -loglevel quiet \
                -f lavfi -i "sine=frequency=1000:duration=0.08" 2>/dev/null && return
            ;;
    esac
    print -n $'\a' > /dev/tty 2>/dev/null
}

_smart_py_notify() {
    (( SMART_PY_NOTIFY )) || return 0
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
    case "$SMART_PY_NOTIFY_LEVEL" in
        all)       : ;;
        important) [[ "$level" == "route" ]] && return 0 ;;
    esac
    notify-send -u "$urgency" -i "$icon" -a "smart-py" -t 3000 "$title" "$body" 2>/dev/null &!
}

_smart_py_event_route() { _smart_py_notify "route" "$1" "${@:2}"; _smart_py_beep; }
_smart_py_event_block() { _smart_py_notify "block" "$1" "${@:2}"; _smart_py_beep; }

# ---------- Stats ----------
_smart_py_stat_incr() {
    (( SMART_PY_STATS )) || return 0
    local key="$1"
    local file="$SMART_PY_STATS_FILE"
    mkdir -p "${file:h}" 2>/dev/null
    if [[ -f "$file" ]] && grep -qF "${key}|" "$file" 2>/dev/null; then
        local cur=$(grep -F "${key}|" "$file" | head -1 | cut -d'|' -f2)
        local new=$((cur + 1))
        awk -F'|' -v OFS='|' -v k="$key" -v n="$new" \
            '$1==k { $2=n } { print }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
        print -r -- "${key}|1" >> "$file"
    fi
}

smart-py-stats() {
    local file="$SMART_PY_STATS_FILE"
    [[ ! -f "$file" ]] && { print "📊 No statistics yet."; return; }
    print "╔══════════════════════════════════════════════════════════════╗"
    print "║            smart-py Usage Statistics                         ║"
    print "╚══════════════════════════════════════════════════════════════╝"
    print ""
    local total=0
    while IFS='|' read -r key val; do
        printf "  %-42s %8d\n" "$key" "$val"
        total=$((total + val))
    done < <(sort -t'|' -k2 -rn "$file")
    print ""
    printf "  %-42s %8d\n" "TOTAL" "$total"
}
smart-py-stats-reset() { : > "$SMART_PY_STATS_FILE"; print "✅ Stats reset."; }

# ---------- Time tracking ----------
_smart_py_track_time() {
    (( SMART_PY_TRACK_TIME )) || return 0
    local elapsed="$1"; shift
    local pm="$1"; shift
    local cmd="$*"
    mkdir -p "${SMART_PY_TIME_FILE:h}" 2>/dev/null
    print -r -- "$(date +%s)|${pm}|${elapsed}|${cmd}" >> "$SMART_PY_TIME_FILE"
}

smart-py-time-saved() {
    local file="$SMART_PY_TIME_FILE"
    [[ ! -f "$file" ]] && { print "⏱️  No data yet."; return; }
    local total=0; local count=0
    while IFS='|' read -r ts pm elapsed cmd; do
        [[ -z "$elapsed" ]] && continue
        [[ "$pm" != "uv" ]] && continue
        total=$((total + $(printf "%.0f" "$elapsed")))
        count=$((count + 1))
    done < "$file"
    (( count == 0 )) && { print "⏱️  No uv ops tracked."; return; }
    local saved=$(awk -v t="$total" -v m="$SMART_PY_TIME_MULTIPLIER" 'BEGIN{printf "%.0f", t*(m-1)}')
    local sh=$((saved/3600)) sm=$(((saved%3600)/60)) ss=$((saved%60))
    local th=$((total/3600)) tm=$(((total%3600)/60)) ts=$((total%60))
    print "╔══════════════════════════════════════════════════════════════╗"
    print "║              smart-py Time-Saved Report                      ║"
    print "╚══════════════════════════════════════════════════════════════╝"
    print ""
    print "  Operations tracked:      $count"
    print "  Total time in uv:        ${th}h ${tm}m ${ts}s"
    print "  Assumed pip multiplier:  ${SMART_PY_TIME_MULTIPLIER}x"
    print "  ─────────────────────────────────────────"
    print "  🎉 Estimated time saved: ${sh}h ${sm}m ${ss}s"
}
smart-py-time-reset() { : > "$SMART_PY_TIME_FILE"; print "✅ Time reset."; }

# ---------- Project detection ----------
_smart_py_detect() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        # Fix #5: don't search above HOME
        if [[ "$PWD" == "$HOME"* && "$dir" == "$HOME" ]]; then
            # Process HOME once, then stop
            if [[ -f "$dir/uv.lock" ]]; then print uv; return; fi
            if [[ -f "$dir/poetry.lock" ]]; then print poetry; return; fi
            if [[ -f "$dir/pdm.lock" ]]; then print pdm; return; fi
            if [[ -f "$dir/Pipfile.lock" || -f "$dir/Pipfile" ]]; then print pipenv; return; fi
            if [[ -f "$dir/pyproject.toml" ]]; then print uv; return; fi
            if [[ -f "$dir/requirements.txt" ]]; then print uv; return; fi
            print ""; return
        fi
        if [[ -f "$dir/uv.lock" ]]; then print uv; return; fi
        if [[ -f "$dir/poetry.lock" ]]; then print poetry; return; fi
        if [[ -f "$dir/pdm.lock" ]]; then print pdm; return; fi
        if [[ -f "$dir/Pipfile.lock" || -f "$dir/Pipfile" ]]; then print pipenv; return; fi
        if [[ -f "$dir/pyproject.toml" ]]; then
            if grep -qE '^\s*\[tool\.poetry\]' "$dir/pyproject.toml" 2>/dev/null; then
                print poetry; return
            fi
            if grep -qE '^\s*\[tool\.pdm\]' "$dir/pyproject.toml" 2>/dev/null; then
                print pdm; return
            fi
            print uv; return
        fi
        if [[ -f "$dir/requirements.txt" ]]; then print uv; return; fi
        if [[ -f "$dir/setup.py" || -f "$dir/setup.cfg" ]]; then print pip; return; fi
        dir="${dir:h}"
    done
    print ""
}

_smart_py_is_global() {
    local a
    for a in "$@"; do
        case "$a" in
            --user|--user=*|--global|--global=*) return 0 ;;
        esac
    done
    return 1
}

_smart_py_has() { command -v "$1" >/dev/null 2>&1; }

# Ensure uv pip has a target: either VIRTUAL_ENV or the active python3
# Returns flags to insert AFTER the subcommand (e.g., `uv pip install --python ...`)
_smart_py_uv_pip_args() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        print -r -- "--python $VIRTUAL_ENV/bin/python"
        return
    fi
    # Fix #4: walk up to find .venv at project root
    local _vd="$PWD"
    while [[ "$_vd" != "/" ]]; do
        if [[ -d "$_vd/.venv" ]]; then
            print -r -- "--python $_vd/.venv/bin/python"
            return
        fi
        _vd="${_vd:h}"
    done
    # No venv → use the python3 currently on PATH (managed by mise)
    local py_path
    py_path="$(command -v python3)"
    if [[ -n "$py_path" ]]; then
        print -r -- "--python $py_path"
    fi
}

# ---------- Dry-run executor ----------
_smart_py_exec() {
    if (( SMART_PY_DRY_RUN )); then
        print -u2 -P "\e[35m[smart-py:DRY-RUN]\e[0m would execute: $*"
        return 0
    fi
    local target_pm="$1"
    [[ "$target_pm" == "command" ]] && target_pm="$2"
    if (( SMART_PY_TRACK_TIME )) && [[ "$target_pm" == "uv" ]]; then
        local start=$(date +%s.%N)
        "$@"
        local rc=$?
        local end=$(date +%s.%N)
        local elapsed=$(awk -v s="$start" -v e="$end" 'BEGIN{printf "%.3f", e-s}')
        _smart_py_track_time "$elapsed" "$target_pm" "$*"
        return $rc
    fi
    "$@"
}

# ---------- Core router ----------
_smart_py_run() {
    local bin="$1"; shift
    local -a args=("$@")
    local pm=$(_smart_py_detect)
    local sub="${args[1]:-}"

    # 1) Global installs (--user / --global)
    if _smart_py_is_global "${args[@]}"; then
        if ! _smart_py_has uv; then
            _smart_py_err "uv not found; falling back to $bin"
            _smart_py_stat_incr "fallback:global→$bin"
            _smart_py_event_block "Fallback to $bin" "uv missing"
            _smart_py_exec command "$bin" "${args[@]}"; return $?
        fi
        # Fix #1: --user routes to uv pip install (library), not uv tool
        # Fix #6: filter ALL flags (start with -) and command words
        # Fix #8: --user=* and --global=* are detected
        # Fix: preserve ALL flags (--upgrade, -r, --no-cache-dir, ...)
        # Only strip: --user, --global, and the leading command word
        local -a _gargs=()
        local _a
        local _is_user=0
        local _seen_cmd=0
        for _a in "${args[@]}"; do
            case "$_a" in
                --user) _is_user=1; continue ;;
                --global) continue ;;
                install|i|add)
                    if (( !_seen_cmd )); then
                        _seen_cmd=1
                        continue
                    fi
                    ;;
            esac
            _gargs+=("$_a")
        done
        (( ${#_gargs[@]} == 0 )) && { _smart_py_err "no arguments given"; return 1; }
        if (( _is_user )); then
            local _extra=$(_smart_py_uv_pip_args)
            _smart_py_stat_incr "global→uv-pip-user"
            _smart_py_log "user install → uv pip install --user ${_gargs[*]}"
            _smart_py_event_route "User install" "→ uv pip install --user ${_gargs[*]}"
            _smart_py_exec command uv pip install --user ${=_extra} "${_gargs[@]}"
            return $?
        fi
        _smart_py_stat_incr "global→uv-tool"
        _smart_py_log "global op → uv tool install ${_gargs[*]}"
        _smart_py_event_route "Global install" "→ uv tool install ${_gargs[*]}"
        _smart_py_exec command uv tool install "${_gargs[@]}"
        return $?
    fi

    # 2) No project context
    if [[ -z "$pm" ]]; then
        case "$sub" in
            install|i|add|uninstall|un|remove|rm|list|show|freeze|download|check|wheel)
                if _smart_py_has uv; then
                    local _extra=$(_smart_py_uv_pip_args)
                    local _sub="${args[1]}"
                    local -a _rest=("${args[@]:1}")
                    _smart_py_stat_incr "nocontext→uv"
                    _smart_py_log "no project → uv pip ${_sub} ${_extra} ${_rest[*]}"
                    _smart_py_event_route "No project" "→ uv pip ${_sub} ${_rest[*]}"
                    _smart_py_exec command uv pip "${_sub}" ${=_extra} "${_rest[@]}"
                    return $?
                fi
                ;;
        esac
        _smart_py_stat_incr "passthrough→$bin"
        _smart_py_exec command "$bin" "${args[@]}"; return $?
    fi

    # 3) Strict mode
    if (( SMART_PY_STRICT )) && [[ "$bin" == "pip" || "$bin" == "pip3" ]]; then
        _smart_py_err "pip is blocked (SMART_PY_STRICT=1). Use 'pip-real'."
        _smart_py_stat_incr "blocked:strict-pip"
        _smart_py_event_block "pip blocked" "SMART_PY_STRICT=1"
        return 1
    fi

    # 4) Project uses pip itself → passthrough if PROTECT off
    if [[ "$pm" == "pip" ]]; then
        if (( SMART_PY_PROTECT )); then
            _smart_py_warn "project uses classic pip; running uv pip as fast drop-in"
            _smart_py_stat_incr "upgrade:pip→uv"
            local _extra=$(_smart_py_uv_pip_args)
            _smart_py_exec command uv pip ${=_extra} "${args[@]}"; return $?
        fi
        _smart_py_stat_incr "passthrough:$bin"
        _smart_py_exec command "$bin" "${args[@]}"; return $?
    fi

    # 5) Route to correct tool based on project type
    case "$pm" in
        uv)
            case "$sub" in
                install|i|add)
                    # Fix #3: detect flags uv add doesn't support → use uv pip
                    local _use_pip=0
                    local _a
                    for _a in "${args[@]:1}"; do
                        case "$_a" in
                            -r|-e|-t|--target|--index-url|--extra-index-url|--find-links|-f|-c|--constraint|--no-deps|--upgrade|-U|--force-reinstall|--no-cache-dir|--require-hashes)
                                _use_pip=1; break ;;
                        esac
                    done
                    if (( _use_pip )); then
                        local _extra=$(_smart_py_uv_pip_args)
                        _smart_py_stat_incr "$bin→uv:pip-install"
                        _smart_py_log "$bin install → uv pip install ${_extra}"
                        _smart_py_event_route "$bin → uv pip install" "${args[*]:1}"
                        _smart_py_exec command uv pip install ${=_extra} "${args[@]:1}"
                    else
                        _smart_py_stat_incr "$bin→uv:add"
                        _smart_py_log "$bin install → uv add ${args[*]:1}"
                        _smart_py_event_route "$bin → uv add" "${args[*]:1}"
                        _smart_py_exec command uv add "${args[@]:1}"
                    fi ;;
                uninstall|un|remove|rm)
                    _smart_py_stat_incr "$bin→uv:remove"
                    _smart_py_log "$bin uninstall → uv remove ${args[*]:1}"
                    _smart_py_event_route "$bin → uv remove" "${args[*]:1}"
                    _smart_py_exec command uv remove "${args[@]:1}" ;;
                list|freeze|show)
                    _smart_py_stat_incr "$bin→uv:list"
                    _smart_py_log "$bin $sub → uv pip $sub"
                    local _extra=$(_smart_py_uv_pip_args)
                    _smart_py_exec command uv pip ${=_extra} "${args[@]}" ;;
                sync|lock|run)
                    _smart_py_stat_incr "$bin→uv:$sub"
                    _smart_py_log "$bin $sub → uv $sub"
                    _smart_py_exec command uv "${args[@]}" ;;
                *)
                    _smart_py_stat_incr "$bin→uv:other"
                    _smart_py_log "$bin ${args[*]} → uv pip ${args[*]}"
                    local _extra=$(_smart_py_uv_pip_args)
                    _smart_py_exec command uv pip ${=_extra} "${args[@]}" ;;
            esac
            ;;
        poetry)
            if ! _smart_py_has poetry; then
                _smart_py_err "poetry not found; using uv instead"
                _smart_py_stat_incr "fallback:poetry→uv"
                local _extra=$(_smart_py_uv_pip_args)
                _smart_py_exec command uv pip ${=_extra} "${args[@]}"
                return $?
            fi
            case "$sub" in
                install|i|add)
                    _smart_py_stat_incr "$bin→poetry:add"
                    _smart_py_log "$bin install → poetry add"
                    _smart_py_event_route "$bin → poetry add" "${args[*]:1}"
                    _smart_py_exec command poetry add "${args[@]:1}" ;;
                uninstall|un|remove|rm)
                    _smart_py_stat_incr "$bin→poetry:remove"
                    _smart_py_exec command poetry remove "${args[@]:1}" ;;
                sync|lock)
                    _smart_py_stat_incr "$bin→poetry:$sub"
                    _smart_py_exec command poetry "${args[@]}" ;;
                *)
                    _smart_py_stat_incr "$bin→poetry:other"
                    _smart_py_exec command poetry "${args[@]}" ;;
            esac
            ;;
        pdm)
            if ! _smart_py_has pdm; then
                _smart_py_err "pdm not found; using uv instead"
                _smart_py_stat_incr "fallback:pdm→uv"
                local _extra=$(_smart_py_uv_pip_args)
                _smart_py_exec command uv pip ${=_extra} "${args[@]}"
                return $?
            fi
            case "$sub" in
                install|i|add)
                    _smart_py_stat_incr "$bin→pdm:add"
                    _smart_py_exec command pdm add "${args[@]:1}" ;;
                uninstall|un|remove|rm)
                    _smart_py_stat_incr "$bin→pdm:remove"
                    _smart_py_exec command pdm remove "${args[@]:1}" ;;
                *)
                    _smart_py_stat_incr "$bin→pdm:other"
                    _smart_py_exec command pdm "${args[@]}" ;;
            esac
            ;;
        pipenv)
            if ! _smart_py_has pipenv; then
                _smart_py_err "pipenv not found; using uv instead"
                _smart_py_stat_incr "fallback:pipenv→uv"
                local _extra=$(_smart_py_uv_pip_args)
                _smart_py_exec command uv pip ${=_extra} "${args[@]}"
                return $?
            fi
            _smart_py_stat_incr "$bin→pipenv"
            _smart_py_exec command pipenv "${args[@]}"
            ;;
        *)
            _smart_py_stat_incr "passthrough:$bin"
            _smart_py_exec command "$bin" "${args[@]}" ;;
    esac
    return $?
}

# ---------- Public functions ----------
pip()  { _smart_py_run pip  "$@"; }
pip3() { _smart_py_run pip3 "$@"; }

pipx() {
    local pm=$(_smart_py_detect)
    if _smart_py_has uv; then
        _smart_py_stat_incr "pipx→uv-tool"
        _smart_py_log "pipx → uv tool $*"
        _smart_py_event_route "pipx → uv tool" "$*"
        _smart_py_exec command uv tool "$@"
    else
        _smart_py_stat_incr "pipx:passthrough"
        _smart_py_exec command pipx "$@"
    fi
}

# ---------- Escape hatches ----------
alias pip-real='command pip'
alias pip3-real='command pip3'
alias pipx-real='command pipx'

# ---------- Utility commands ----------
smart-py-where() {
    local pm=$(_smart_py_detect)
    [[ -z "$pm" ]] && print "📍 No project. Default: $SMART_PY_DEFAULT" \
                    || print "📍 Detected PM for $PWD: $pm"
}

smart-py-log() {
    local n="${1:-20}"
    print "📜 Last $n events ($SMART_PY_LOG_FILE):"; print ""
    tail -n "$n" "$SMART_PY_LOG_FILE" 2>/dev/null || print "No log yet."
}
smart-py-log-clear() { : > "$SMART_PY_LOG_FILE"; print "✅ Log cleared."; }

smart-py-verbose() { if (( SMART_PY_VERBOSE )); then SMART_PY_VERBOSE=0; print "🔇 Verbose: OFF"; else SMART_PY_VERBOSE=1; print "🔊 Verbose: ON"; fi; _smart_py_state_save; }
smart-py-notify()  { if (( SMART_PY_NOTIFY )); then SMART_PY_NOTIFY=0; print "🔕 Notifications: OFF"; else SMART_PY_NOTIFY=1; print "🔔 Notifications: ON"; fi; _smart_py_state_save; }
smart-py-beep()    { if (( SMART_PY_BEEP )); then SMART_PY_BEEP=0; print "🔇 Beep: OFF"; else SMART_PY_BEEP=1; print "🔊 Beep: ON"; _smart_py_beep; fi; _smart_py_state_save; }
smart-py-dry-run() { if (( SMART_PY_DRY_RUN )); then SMART_PY_DRY_RUN=0; print "▶️  Dry-run: OFF"; else SMART_PY_DRY_RUN=1; print "🧪 Dry-run: ON"; fi; _smart_py_state_save; }
smart-py-strict()  { if (( SMART_PY_STRICT )); then SMART_PY_STRICT=0; print "🟢 Strict: OFF"; else SMART_PY_STRICT=1; print "🔴 Strict: ON"; fi; _smart_py_state_save; }
smart-py-protect() { if (( SMART_PY_PROTECT )); then SMART_PY_PROTECT=0; print "🟢 Protect: OFF"; else SMART_PY_PROTECT=1; print "🔴 Protect: ON"; fi; _smart_py_state_save; }

smart-py-status() {
    print "╔══════════════════════════════════════════════════════════════╗"
    print "║                    smart-py Status                           ║"
    print "╚══════════════════════════════════════════════════════════════╝"
    print ""
    print "Paths:"
    print "  Config:              $SMART_PY_CONFIG_FILE"
    print "  State:               $SMART_PY_STATE_FILE"
    print "  Log:                 $SMART_PY_LOG_FILE"
    print "  Stats:               $SMART_PY_STATS_FILE"
    print "  Time:                $SMART_PY_TIME_FILE"
    print ""
    print "Configuration:"
    print "  Default PM:          $SMART_PY_DEFAULT"
    print "  Global PM:           $SMART_PY_GLOBAL_PM"
    print "  Strict:              $SMART_PY_STRICT"
    print "  Protect:             $SMART_PY_PROTECT"
    print "  Verbose:             $SMART_PY_VERBOSE"
    print "  Notify:              $SMART_PY_NOTIFY ($SMART_PY_NOTIFY_LEVEL)"
    print "  Beep:                $SMART_PY_BEEP"
    print "  Dry-run:             $SMART_PY_DRY_RUN"
    print "  Track time:          $SMART_PY_TRACK_TIME (×$SMART_PY_TIME_MULTIPLIER)"
    print ""
    print "Current directory:"; smart-py-where
    print ""
    print "Commands:"
    print "  smart-py-status, smart-py-where"
    print "  smart-py-stats, smart-py-stats-reset"
    print "  smart-py-time-saved, smart-py-time-reset"
    print "  smart-py-log [n], smart-py-log-clear"
    print "  smart-py-verbose, smart-py-notify, smart-py-beep"
    print "  smart-py-dry-run, smart-py-strict, smart-py-protect"
}

# ==============================================================================
# End of smart-py.zsh
# ==============================================================================
