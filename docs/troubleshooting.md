# Troubleshooting

Common issues and their solutions.

## The router does not activate

### Symptom

Typing `npm` or `pip` runs the real binary instead of the router:

```bash
type npm
# npm is /usr/bin/npm
```

### Diagnosis

Check if the script is sourced in your `.zshrc`:

```bash
grep -n "smart-pm\|smart-py" ~/.zshrc
```

You should see:

```
[[ -f ~/.config/shell/smart-pm.zsh ]] && source ~/.config/shell/smart-pm.zsh
[[ -f ~/.config/shell/smart-py.zsh ]] && source ~/.config/shell/smart-py.zsh
```

### Fix

1. If the lines are missing, add them:

```bash
cat >> ~/.zshrc << 'EOF'
[[ -f ~/.config/shell/smart-pm.zsh ]] && source ~/.config/shell/smart-pm.zsh
[[ -f ~/.config/shell/smart-py.zsh ]] && source ~/.config/shell/smart-py.zsh
EOF
```

2. Reload:

```bash
source ~/.zshrc
```

3. Verify:

```bash
type npm
# npm is a shell function from /home/you/.config/shell/smart-pm.zsh
```

## Syntax errors on shell startup

### Symptom

You see a message like:

```
/home/you/.config/shell/smart-py.zsh:401: parse error near `else'
```

### Diagnosis

The script was corrupted during a manual edit (usually by an automated fix).

### Fix

Restore from a backup:

```bash
ls -t ~/.config/shell/smart-py.zsh.backup-* | head -1
cp $(ls -t ~/.config/shell/smart-py.zsh.backup-* | head -1) ~/.config/shell/smart-py.zsh
source ~/.zshrc
```

If no backup exists, re-install from the GitHub repo.

## `uv pip` errors: "No virtual environment found"

### Symptom

```
error: No virtual environment found; run `uv venv` to create an environment,
or pass `--system` to install into a non-virtual environment
```

### Cause

`uv pip` requires either an active venv or an explicit target Python.

### Fix

The router already handles this by passing `--python <mise-python>`. If you see this error, the router did not detect your Python installation. Check:

```bash
command -v python3
python3 --version
```

If Python is missing, install it via mise:

```bash
mise use -g python@latest
```

## `uv pip` errors: "unexpected argument '--system'"

### Symptom

```
error: unexpected argument '--system' found
```

### Cause

An older version of smart-py passed `--system` in the wrong position.

### Fix

Update smart-py from the latest GitHub release:

```bash
cp ~/Projects/bluefin-smart-routers/scripts/smart-py.zsh ~/.config/shell/
source ~/.zshrc
```

## `pip install --user` installs a CLI tool instead of a library

### Symptom

You run:

```bash
pip install --user requests
```

And you get an error saying `uv tool install` cannot find `requests`.

### Cause

An older version of smart-py incorrectly routed `--user` installs to `uv tool install`.

### Fix

Update smart-py from the latest GitHub release. The current version routes `--user` installs to `uv pip install --user`, which handles libraries correctly.

## `pip install -r requirements.txt` fails

### Symptom

```
error: unrecognized option `-r'
```

### Cause

`uv add` does not support `-r`. The router must use `uv pip install` instead.

### Fix

Update smart-py to version 1.0.0 or later. The router auto-detects `-r`, `-e`, and similar flags and routes them to `uv pip install`.

## `pnpm` command not found after installing via mise

### Symptom

```bash
pnpm --version
# command not found: pnpm
```

### Cause

mise installed pnpm but the shim is not in PATH.

### Fix

Reload your shell:

```bash
source ~/.zshrc
```

If that fails, check the shim:

```bash
ls ~/.local/share/mise/shims/pnpm
mise reshim
```

## Package installed via `uv tool` cannot be imported in Python

### Symptom

```bash
uv tool install requests
python3 -c "import requests"
# ModuleNotFoundError: No module named 'requests'
```

### Cause

`uv tool install` installs **CLI tools** in isolated environments. It does not install **libraries** for your Python interpreter.

### Fix

For libraries, use `pip install --user`:

```bash
pip install --user requests
python3 -c "import requests; print(requests.__version__)"
```

Rule of thumb:

- **Tool** (has a CLI command): `pipx install <tool>` or `pip install --global <tool>`
- **Library** (imported in code): `pip install <library>` or `pip install --user <library>`

## Command history leaks secrets

### Symptom

You accidentally typed an API key on the command line, and it is now in `.zsh_history`.

### Fix

Remove specific line:

```bash
sed -i '/your-secret-here/d' ~/.zsh_history
fc -R ~/.zsh_history
```

Remove entire history:

```bash
> ~/.zsh_history
fc -R ~/.zsh_history
```

## Router logs are too noisy

### Symptom

Every command prints `[smart-py] ...` or `[smart-pm] ...` lines.

### Fix

Toggle verbose mode:

```bash
smart-pm-verbose
smart-py-verbose
```

Or disable permanently in the config files:

```bash
# ~/.config/smart-pm/config
SMART_PM_VERBOSE=0

# ~/.config/smart-py/config
SMART_PY_VERBOSE=0
```

Then reload:

```bash
smart-pm-reload
smart-py-reload
```

## `smart-py-reload: command not found`

### Symptom

You try `smart-py-reload` but it does not exist.

### Cause

Only `smart-pm-reload` is defined. `smart-py` has `smart-py-status` but no reload (yet).

### Fix

Manual reload:

```bash
source ~/.config/shell/smart-py.zsh
```

Or reload all shell config:

```bash
source ~/.zshrc
```

## Desktop notifications do not appear

### Symptom

You expect a notification on routing, but nothing shows.

### Diagnosis

Check if `notify-send` is available:

```bash
command -v notify-send
```

### Fix

Install `libnotify` if missing:

```bash
# On Bluefin:
rpm-ostree install libnotify
# then reboot
```

Or disable notifications:

```bash
smart-pm-notify       # toggle off
smart-py-notify
```

## Log file is empty

### Symptom

`smart-py-log` prints "No log yet".

### Diagnosis

Check the log file path:

```bash
echo $SMART_PY_LOG_FILE
ls -la $(dirname $SMART_PY_LOG_FILE)
```

### Fix

Ensure the cache directory exists:

```bash
mkdir -p ~/.cache
touch ~/.cache/smart-py.log
```

Then run a command that triggers routing, and check again.

## Getting more help

If your issue is not listed here:

1. **Check the log** for the specific routing decision:
   ```bash
   smart-pm-log 50
   smart-py-log 50
   ```

2. **Check the status**:
   ```bash
   smart-pm-status
   smart-py-status
   ```

3. **Enable dry-run** to see what would happen without executing:
   ```bash
   smart-pm-dry-run
   smart-py-dry-run
   npm install <pkg>       # shows the routed command
   ```

4. **Open an issue** on GitHub with:
   - The command you ran.
   - The output (or error).
   - The relevant log lines.