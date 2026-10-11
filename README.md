# bluefin-smart-routers

Smart package manager routers for **Linux Bluefin** (and other immutable Fedora-based distros).

Two zsh scripts that transparently route `npm`/`npx`/`yarn`/`bun` and `pip`/`pip3`/`pipx` to their faster, more modern equivalents — without changing your workflow.

## What's Inside

| Script | Routes | To |
|---|---|---|
| **`smart-pm.zsh`** | `npm`, `npx`, `yarn`, `bun` | `pnpm` |
| **`smart-py.zsh`** | `pip`, `pip3`, `pipx` | `uv` |

Both scripts share the same philosophy:

- **Zero-config**: type your usual commands, they get routed automatically.
- **Project-aware**: detects `pnpm-lock.yaml`, `uv.lock`, `poetry.lock`, etc.
- **Safe**: dry-run mode, strict mode, logging, stats, escape hatches.
- **Non-invasive**: nothing is deleted or modified — just routed.

## Features

### smart-pm (Node.js ecosystem)
- Detects project type via lockfiles.
- Global installs go to pnpm.
- Corepack integration for auto version switching.
- Blocks npm inside pnpm projects (protective mode).
- Usage stats, time-saved tracking, desktop notifications.

### smart-py (Python ecosystem)
- Detects project type via lockfiles (`uv.lock`, `poetry.lock`, `pdm.lock`, `Pipfile`).
- Uses `uv pip` for library installs, `uv tool` for CLI tools.
- Handles `--user`, `--global`, `-r`, `-e`, `--upgrade` correctly.
- Auto-detects `.venv` at project root.
- Falls back gracefully when poetry/pdm/pipenv are missing.

## Install

### 1. Clone the repo

    git clone https://github.com/sbens-dev/bluefin-smart-routers.git
    cd bluefin-smart-routers

### 2. Install scripts

    mkdir -p ~/.config/shell
    cp scripts/smart-pm.zsh ~/.config/shell/
    cp scripts/smart-py.zsh ~/.config/shell/
    chmod +x ~/.config/shell/smart-*.zsh

### 3. Hook into zsh

Add these lines to `~/.zshrc`:

    [[ -f ~/.config/shell/smart-pm.zsh ]] && source ~/.config/shell/smart-pm.zsh
    [[ -f ~/.config/shell/smart-py.zsh ]] && source ~/.config/shell/smart-py.zsh

### 4. Reload your shell

    source ~/.zshrc

## Prerequisites

- **zsh** (required)
- **Node.js + pnpm** (for smart-pm) — install via [mise](https://mise.jdx.dev/)
- **Python + uv** (for smart-py) — install via mise or uv's installer
- **Linux Bluefin** or any Fedora Atomic / Silverblue-based system (recommended)

## Usage

### Basic

Just use your normal commands:

    npm install lodash           # → pnpm install lodash
    pip install requests         # → uv pip install --python <mise-python> requests
    pip install --user black     # → uv pip install --user --python <mise-python> black
    pipx install ruff            # → uv tool install ruff

### Diagnostics

    smart-pm-status              # Full status report
    smart-pm-where               # Detected PM for current dir
    smart-pm-log 20              # Last 20 routing decisions
    smart-pm-stats               # Usage statistics
    smart-pm-time-saved          # Estimated time saved

    smart-py-status
    smart-py-where
    smart-py-log 20
    smart-py-stats
    smart-py-time-saved

### Control

    smart-pm-dry-run             # Toggle simulation mode
    smart-pm-strict              # Block npm completely
    smart-py-dry-run
    smart-py-strict

### Escape Hatches

    npm-real install <pkg>       # Real npm, no routing
    pip-real install <pkg>       # Real pip, no routing
    command npm install <pkg>    # Same as above

## Design Principles

1. **Never modify the system image.** All installs go to user-space.
2. **Never delete anything.** Routing only.
3. **Fail gracefully.** Missing tool? Fall back to a working alternative.
4. **Be transparent.** Every routing decision is logged.
5. **Preserve user intent.** Flags are passed through faithfully.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Built for the [Bluefin](https://projectbluefin.io/) community.