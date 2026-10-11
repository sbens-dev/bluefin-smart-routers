# bluefin-smart-routers

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Latest Release](https://img.shields.io/github/v/release/sbens-dev/bluefin-smart-routers)](https://github.com/sbens-dev/bluefin-smart-routers/releases)
[![Platform: Linux Bluefin](https://img.shields.io/badge/platform-Linux%20Bluefin-blue)](https://projectbluefin.io/)
[![Shell: zsh](https://img.shields.io/badge/shell-zsh-89e051)](https://www.zsh.org/)

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

- Detects project type via lockfiles (`pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, `package-lock.json`).
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

```bash
git clone https://github.com/sbens-dev/bluefin-smart-routers.git
cd bluefin-smart-routers
```

### 2. Install scripts

```bash
mkdir -p ~/.config/shell
cp scripts/smart-pm.zsh ~/.config/shell/
cp scripts/smart-py.zsh ~/.config/shell/
chmod +x ~/.config/shell/smart-*.zsh
```

### 3. Hook into zsh

Add these lines to `~/.zshrc`:

```bash
[[ -f ~/.config/shell/smart-pm.zsh ]] && source ~/.config/shell/smart-pm.zsh
[[ -f ~/.config/shell/smart-py.zsh ]] && source ~/.config/shell/smart-py.zsh
```

### 4. Reload your shell

```bash
source ~/.zshrc
```

## Prerequisites

- **zsh** (required)
- **Node.js + pnpm** (for smart-pm) — install via [mise](https://mise.jdx.dev/)
- **Python + uv** (for smart-py) — install via mise or uv's installer
- **Linux Bluefin** or any Fedora Atomic / Silverblue-based system (recommended)

## Usage

### Basic

Just use your normal commands:

```bash
npm install lodash           # → pnpm install lodash
pip install requests         # → uv pip install --python <mise-python> requests
pip install --user black     # → uv pip install --user --python <mise-python> black
pipx install ruff            # → uv tool install ruff
```

### Diagnostics

```bash
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
```

### Control

```bash
smart-pm-dry-run             # Toggle simulation mode
smart-pm-strict              # Block npm completely
smart-pm-verbose             # Toggle log messages

smart-py-dry-run
smart-py-strict
smart-py-verbose
```

### Escape Hatches

```bash
npm-real install <pkg>       # Real npm, no routing
pip-real install <pkg>       # Real pip, no routing
command npm install <pkg>    # Same as above
```

## Documentation

See [`docs/`](docs/) for detailed guides:

- [Migration Guide](docs/migration.md) — moving from raw npm/pip workflows.
- [Troubleshooting](docs/troubleshooting.md) — 20+ common issues and fixes.

## Design Principles

1. **Never modify the system image.** All installs go to user-space.
2. **Never delete anything.** Routing only — no files are touched.
3. **Fail gracefully.** Missing tool? Fall back to a working alternative.
4. **Be transparent.** Every routing decision is logged and (optionally) shown.
5. **Preserve user intent.** Flags are passed through faithfully.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Built for the [Bluefin](https://projectbluefin.io/) community.