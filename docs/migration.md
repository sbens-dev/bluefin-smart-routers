# Migration Guide

How to migrate from raw `npm`/`pip` workflows to the smart routers.

## Before You Start

Make sure you have installed both scripts. See the [main README](../README.md).

Verify installation:

```bash
type npm | head -1
type pip | head -1
```

Expected output:

```
npm is a shell function from /home/you/.config/shell/smart-pm.zsh
pip is a shell function from /home/you/.config/shell/smart-py.zsh
```

If you see file paths instead of "shell function", the scripts are not loaded. Check `~/.zshrc`.

## Migrating Node.js Projects

### From npm to pnpm

**Do not** run `pnpm import` or convert lockfiles manually. The router handles it.

**Steps:**

1. `cd` into your project.
2. Run `npm install` as usual.
3. The router detects the absence of `pnpm-lock.yaml`, so it creates one via `pnpm install`.
4. You now have a `pnpm-lock.yaml` — subsequent commands will use pnpm consistently.

**Optional cleanup:**

```bash
rm package-lock.json
rm -rf node_modules
npm install
```

### Working with yarn projects

The router detects `yarn.lock` and uses `yarn` as-is, unless you opt in to convert. To convert:

```bash
rm yarn.lock
npm install
```

### Working with bun projects

Same as yarn. `bun.lockb` is detected and `bun` is used. To convert:

```bash
rm bun.lockb bun.lock 2>/dev/null
npm install
```

## Migrating Python Projects

### From pip + requirements.txt to uv

**Do not** rename files. The router handles both styles.

**Steps:**

1. `cd` into your project.
2. Run `pip install -r requirements.txt`.
3. The router detects `requirements.txt` and uses `uv pip install`.
4. To upgrade to `uv.lock`, run:

```bash
uv lock
```

**Optional cleanup:**

```bash
deactivate 2>/dev/null
uv venv
source .venv/bin/activate
pip install -e .
```

### From poetry

The router respects `poetry.lock` and uses `poetry` if installed. To migrate to uv:

```bash
rm poetry.lock
uv init .
uv add $(cat requirements.txt)
uv lock
```

### From pipenv

Similar approach:

```bash
rm Pipfile Pipfile.lock
uv init .
uv lock
```

## Global Tools

### Node.js CLI tools

**Before:** `npm install -g <tool>`
**After:** routed to `pnpm add -g <tool>`

Nothing changes for you. The binary ends up in `~/.local/share/pnpm/bin/`.

### Python CLI tools

**Before:** `pipx install <tool>` or `pip install --user <tool>`
**After:**

- `pipx install <tool>` → `uv tool install <tool>`
- `pip install --user <tool>` → `uv pip install --user <tool>` (library)
- `pip install --global <tool>` → `uv tool install <tool>` (tool)

**Recommendation:** use `pipx install` for tools, `pip install --user` for libraries you want to import.

## Reverting to Raw npm/pip

If you need the original behavior temporarily:

```bash
npm-real install <pkg>
pip-real install <pkg>
command npm install <pkg>
```

Or disable routing globally:

```bash
smart-pm-strict
smart-py-strict
```

To restore normal behavior:

```bash
smart-pm-strict
smart-py-strict
```

## Verifying the Migration

### For Node.js

```bash
smart-pm-where
ls pnpm-lock.yaml
```

### For Python

```bash
smart-py-where
ls uv.lock
```

## Common Pitfalls

| Problem | Cause | Fix |
|---|---|---|
| `command not found: pnpm` | pnpm not installed | `mise use -g pnpm@latest` |
| `command not found: uv` | uv not installed | `mise use -g uv@latest` |
| Router doesn't activate | `.zshrc` not sourced | `source ~/.zshrc` |
| Router activates but uses npm | Existing `package-lock.json` | Delete it, reinstall |
| Python libs not importable | Used `uv tool` for a library | Use `pip install --user` instead |

## Getting Help

- Check the log: `smart-pm-log 50` or `smart-py-log 50`
- Check status: `smart-pm-status` or `smart-py-status`
- Open an issue on GitHub.