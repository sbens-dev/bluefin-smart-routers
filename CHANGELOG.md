# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- `smart-py-reload` command for consistency with `smart-pm-reload`.
- Windows compatibility (via Git Bash / WSL).
- Support for `pixi` and `pdm` as first-class routers.
- Integration tests using `bats-core`.
- Homebrew formula for easy installation.

## [1.0.1] - 2026-10-11

### Added

- **Community files:**
  - `CONTRIBUTING.md` — development setup, style guide, and PR process.
  - `SECURITY.md` — vulnerability reporting and security design principles.
  - `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1.
  - `.editorconfig` — consistent style across editors.
- **GitHub infrastructure:**
  - `.github/workflows/syntax-check.yml` — automated `zsh -n` checks on every push and PR.
  - `.github/ISSUE_TEMPLATE/bug_report.md` — structured bug reports.
  - `.github/ISSUE_TEMPLATE/feature_request.md` — structured feature requests.
  - `.github/ISSUE_TEMPLATE/config.yml` — issue chooser with quick links.
  - `.github/PULL_REQUEST_TEMPLATE.md` — PR checklist and description.
- **Documentation improvements:**
  - `README.md` — CI badge, syntax highlighting, community links.
  - `docs/migration.md` — step-by-step migration from raw npm/pip.
  - `docs/troubleshooting.md` — 20+ common issues and fixes.

### Changed

- Repository description and topics (12 topics for discoverability).

## [1.0.0] - 2026-10-11

### Added

- **smart-pm.zsh**: A unified package manager router for Node.js ecosystem.
  - Routes `npm`, `npx`, `yarn`, `bun` to `pnpm`.
  - Project detection via `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, `package-lock.json`.
  - Corepack integration for automatic version switching.
  - Protective mode blocks `npm` inside pnpm projects.
  - Global installs go to pnpm.
  - Full logging to `~/.cache/smart-pm.log`.
  - Usage statistics in `~/.cache/smart-pm-stats`.
  - Time-saved tracking in `~/.cache/smart-pm-time`.
  - Dry-run mode for safe testing.
  - Desktop notifications (via `notify-send`) and audio feedback.
  - Git-based config sync across machines.
  - Escape hatches: `npm-real`, `npx-real`, `yarn-real`, `bun-real`.

- **smart-py.zsh**: A unified package manager router for Python ecosystem.
  - Routes `pip`, `pip3`, `pipx` to `uv`.
  - Project detection via `uv.lock`, `poetry.lock`, `pdm.lock`, `Pipfile`.
  - `uv pip` for library installs, `uv tool` for CLI tools.
  - Handles `--user`, `--global`, `-r`, `-e`, `--upgrade` correctly.
  - Auto-detects `.venv` at project root (walks up directories).
  - Falls back gracefully when poetry, pdm, or pipenv are missing.
  - Full logging, stats, time tracking, dry-run, notifications.
  - Escape hatches: `pip-real`, `pip3-real`, `pipx-real`.

- **Documentation**:
  - `README.md` with full installation and usage guide.
  - `docs/migration.md` for migrating from npm/pip workflows.
  - `docs/troubleshooting.md` with 20+ common issues and fixes.

### Fixed

- `--user` installs correctly route to `uv pip install --user` (not `uv tool`).
- `-r`, `-e`, `--target` flags route to `uv pip install` (not `uv add`).
- All flags (`--upgrade`, `-r`, etc.) are preserved during routing.
- `.venv` detection walks up to project root, not just `$PWD`.
- Project detection stops at `$HOME`, avoiding false positives in `/tmp`.
- Syntax errors in `case`/`if` blocks resolved.
- `--python` flag placed after subcommand in `uv pip` calls.

### Security

- Safe `$HOME` expansion in config loader (prevents arbitrary command execution).
- Non-interactive `read` guard (prevents hanging in scripts).
- Regex escape in package.json lookups (prevents false positives).

## [0.1.0] - 2026-10-10

### Added

- Initial prototype of `smart-pm.zsh` (Node.js router).
- Initial prototype of `smart-py.zsh` (Python router).

---

## Version History Summary

| Version | Date | Highlights |
|---|---|---|
| 1.0.1 | 2026-10-11 | Community files, CI, GitHub templates |
| 1.0.0 | 2026-10-11 | First stable release — both routers production-ready |
| 0.1.0 | 2026-10-10 | Initial prototypes |

## Links

- [Repository](https://github.com/sbens-dev/bluefin-smart-routers)
- [Issue Tracker](https://github.com/sbens-dev/bluefin-smart-routers/issues)
- [Latest Release](https://github.com/sbens-dev/bluefin-smart-routers/releases/latest)