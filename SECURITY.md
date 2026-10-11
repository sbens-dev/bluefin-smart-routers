# Security Policy

## Supported Versions

We actively support and patch the following versions:

| Version | Supported | Notes |
|---|---|---|
| 1.0.x   | ✅ | Current stable release |
| < 1.0   | ❌ | Prototypes, please upgrade |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, **please do not open a public issue**. Instead, report it privately so we can address it before disclosure.

### How to Report

**Option 1: GitHub Private Advisory** (preferred)

1. Go to the [Security tab](https://github.com/sbens-dev/bluefin-smart-routers/security/advisories/new).
2. Click **"Report a vulnerability"**.
3. Fill in the details.

**Option 2: Email**

Send an email to the maintainer with:

- A description of the vulnerability.
- Steps to reproduce.
- Potential impact.
- Any suggested fixes (optional).

### What to Include

Please provide:

- **Type of vulnerability** (e.g., command injection, path traversal, symlink attack).
- **Affected component** (`smart-pm.zsh`, `smart-py.zsh`, or both).
- **Affected version** (`smart-pm --version`, `smart-py --version`, or git commit hash).
- **Reproduction steps** — minimal, complete, and verifiable.
- **Impact assessment** — what an attacker could achieve.
- **Proof of concept** (if applicable) — a small script or command.
- **Environment** — OS, zsh version, mise version.

### What We Commit To

- **Acknowledge** your report within **48 hours**.
- **Provide an initial assessment** within **7 days**.
- **Keep you informed** of our progress.
- **Credit you** in the fix announcement (unless you prefer to remain anonymous).
- **Not take legal action** against researchers acting in good faith.

### Disclosure Timeline

We follow **coordinated disclosure**:

1. **Day 0** — You report the vulnerability privately.
2. **Day 1–7** — We triage and assess severity.
3. **Day 7–30** — We develop and test a fix.
4. **Day 30–60** — We release a patch and publish a security advisory.
5. **Day 60+** — You may disclose publicly.

If the vulnerability is **critical**, we may accelerate this timeline.

## Scope

### In Scope

Security issues in the code itself:

- **Command injection** — e.g., a package name that escapes shell quoting.
- **Path traversal** — e.g., a project path that reads files outside the project.
- **Symlink attacks** — e.g., a malicious `.venv` symlink.
- **Config file injection** — e.g., a malicious `.config/smart-py/config`.
- **TOCTOU** — race conditions in file operations.
- **Privilege escalation** — e.g., a routing that accidentally escalates.
- **Information disclosure** — e.g., secrets leaked to logs or notifications.

### Out of Scope

- **Vulnerabilities in upstream tools** (`uv`, `pnpm`, `mise`, `npm`, `pip`). Report those to the respective projects.
- **Social engineering attacks** against the user.
- **Physical access** to the user's machine.
- **Attacks requiring already-root access**.
- **Denial of service on your own machine** (routing is inherently local).

## Security Design Principles

Our code follows these principles:

1. **No elevated privileges** — neither script ever runs `sudo`. Everything is user-space.
2. **No external network calls** — except when you explicitly run an install command (which calls `uv` or `pnpm`, which call registries).
3. **No telemetry** — we don't phone home, ever.
4. **No deletions** — we route commands, we don't remove files.
5. **Safe `$HOME` expansion** — configs expand `$HOME` but do not execute arbitrary shell.
6. **Quoted variables everywhere** — all variable expansions are quoted to prevent word splitting and globbing.
7. **`command -v` guards** — we never assume a tool exists; we check first.
8. **Opt-in dry-run** — you can preview any routing before it executes.
9. **Logging is local** — logs go to `~/.cache/`, never leave your machine.
10. **Escape hatches** — `npm-real`, `pip-real`, etc., always bypass routing.

## Known Risks

The routers are inherently a form of **shell aliasing**. As such:

- **They modify the behavior of common commands**. If you have scripts that depend on `npm` being the real npm, use `command npm` or `npm-real` to bypass.
- **They read `.zshrc` and config files**. Keep those files secure (mode `0600`).
- **They write to `~/.cache/`**. Ensure your cache directory is not world-readable if your logs might contain sensitive information.
- **They log command arguments** to `~/.cache/smart-*.log`. If you pass secrets on the command line, they will appear in the log. We recommend:
  - Using environment variables or config files for secrets.
  - Rotating `~/.cache/smart-*.log` periodically.
  - Setting `SMART_PM_LOG=0` or `SMART_PY_LOG=0` if you want to disable logging.

### Recommended Hardening

For users who want maximum security:

```bash
# Disable logging entirely
echo 'SMART_PM_LOG=0' >> ~/.config/smart-pm/config
echo 'SMART_PY_LOG=0' >> ~/.config/smart-py/config

# Disable notifications (which may appear in screen recordings)
echo 'SMART_PM_NOTIFY=0' >> ~/.config/smart-pm/config
echo 'SMART_PY_NOTIFY=0' >> ~/.config/smart-py/config

# Restrict cache directory permissions
chmod 700 ~/.cache
chmod 600 ~/.cache/smart-*.log ~/.cache/smart-*-stats

# Restrict config directory permissions
chmod 700 ~/.config/smart-pm ~/.config/smart-py
chmod 600 ~/.config/smart-pm/config ~/.config/smart-py/config
```

## Security Advisories

Past security advisories will be listed here as they are published.

| Date | Advisory | Severity | Status |
|---|---|---|---|
| — | None yet | — | — |

## Credits

We thank the following security researchers for responsibly disclosing issues:

- (Your name could be here)

## Questions?

For non-security questions, please use [GitHub Discussions](https://github.com/sbens-dev/bluefin-smart-routers/discussions).

For security questions, use the private channels above.