---
name: Bug Report
about: Report a bug in smart-pm or smart-py
title: '[BUG] '
labels: ['bug', 'needs-triage']
assignees: ''
---

## Description

A clear and concise description of what the bug is.

## Which router?

- [ ] `smart-pm` (Node.js ecosystem — npm/pnpm/yarn/bun)
- [ ] `smart-py` (Python ecosystem — pip/uv)
- [ ] Both
- [ ] Other (please specify below)

## Environment

- **OS**: (e.g., Bluefin 44.20261006)
- **Kernel**: (output of `uname -r`)
- **zsh version**: (output of `zsh --version`)
- **smart-pm version**: (output of `smart-pm --version` or commit hash)
- **smart-py version**: (output of `smart-py --version` or commit hash)
- **mise version**: (output of `mise --version`)
- **pnpm version**: (output of `pnpm --version`)
- **uv version**: (output of `uv --version`)

## Steps to Reproduce

1. Navigate to `...`
2. Run `...`
3. Observe `...`

## Expected Behavior

What you expected to happen.

## Actual Behavior

What actually happened.

## Logs

Please attach the relevant log output:

```bash
smart-pm-log 20 > /tmp/smart-pm-log.txt
smart-py-log 20 > /tmp/smart-py-log.txt
```

Attach `smart-pm-log.txt` and/or `smart-py-log.txt`.

## Screenshots

If applicable, add screenshots to help explain the problem.

## Additional Context

- Did this work before? If so, when did it break?
- Any relevant configuration in `~/.config/smart-pm/config` or `~/.config/smart-py/config`?
- Any other details that might help.

## Checklist

- [ ] I have read the [troubleshooting guide](../../docs/troubleshooting.md).
- [ ] I have searched existing issues to avoid duplicates.
- [ ] I have provided all required environment details above.
- [ ] I have attached relevant logs.