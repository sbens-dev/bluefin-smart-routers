# Contributing to bluefin-smart-routers

Thanks for your interest in improving these routers! This document explains how to contribute effectively.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Guidelines](#coding-guidelines)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)

## Code of Conduct

Be respectful, constructive, and patient. We're all here to make Linux package management less painful. Harassment, trolling, or personal attacks are not tolerated.

## How Can I Contribute?

There are many ways to help:

- **Report bugs** — open an issue with details.
- **Suggest features** — open a discussion or issue.
- **Improve docs** — fix typos, clarify sections, add examples.
- **Fix bugs** — submit a pull request.
- **Add tests** — help us build a test suite.
- **Translate** — if you speak another language, we'd love translations.
- **Share** — tell others about the project.

## Development Setup

### 1. Fork and clone

```bash
git clone https://github.com/YOUR-USERNAME/bluefin-smart-routers.git
cd bluefin-smart-routers
```

### 2. Install prerequisites

- **zsh** (required)
- **mise** (recommended for managing Node.js and Python)
- **Node.js + pnpm** (for testing smart-pm)
- **Python + uv** (for testing smart-py)

### 3. Link your fork

```bash
git remote add upstream https://github.com/sbens-dev/bluefin-smart-routers.git
```

### 4. Test locally

Copy the scripts to your shell config directory and source them:

```bash
mkdir -p ~/.config/shell
cp scripts/smart-pm.zsh ~/.config/shell/
cp scripts/smart-py.zsh ~/.config/shell/
echo 'source ~/.config/shell/smart-pm.zsh' >> ~/.zshrc
echo 'source ~/.config/shell/smart-py.zsh' >> ~/.zshrc
source ~/.zshrc
```

Verify:

```bash
type npm    # should be a shell function
type pip    # should be a shell function
```

## Coding Guidelines

### zsh Style

- **Indent**: 4 spaces (no tabs).
- **Naming**: `snake_case` for internal functions (`_smart_pm_*`), `kebab-case` for public commands (`smart-pm-*`).
- **Quoting**: always quote variables: `"$var"`, `"${args[@]}"`.
- **Arrays**: use `local -a` for arrays.
- **Guards**: check for existence before using: `[[ -f "$file" ]] || return 0`.
- **Comments**: explain *why*, not *what*.

### Example

```zsh
_smart_pm_example() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    local -a lines
    while IFS= read -r line; do
        lines+=("$line")
    done < "$file"
    print -r -- "${lines[@]}"
}
```

### Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat`: new feature
- `fix`: bug fix
- `docs`: documentation
- `style`: formatting (no logic change)
- `refactor`: code restructure
- `test`: adding tests
- `chore`: maintenance

**Examples:**

```
feat(smart-py): add pdm router support
fix(smart-pm): preserve --upgrade flag during routing
docs(readme): add badges and syntax highlighting
```

## Submitting Changes

### 1. Create a branch

```bash
git checkout -b feat/my-feature
# or
git checkout -b fix/bug-description
```

### 2. Make your changes

- Edit the scripts in `scripts/`.
- Test locally.
- Run syntax check:

```bash
zsh -n scripts/smart-pm.zsh
zsh -n scripts/smart-py.zsh
```

### 3. Commit

```bash
git add -A
git commit -m "feat(scope): description"
```

### 4. Push

```bash
git push origin feat/my-feature
```

### 5. Open a Pull Request

- Go to your fork on GitHub.
- Click "Compare & pull request".
- Fill in:
  - **What** you changed.
  - **Why** you changed it.
  - **How** you tested it.
- Link related issues: `Closes #123`.

### 6. Review process

- A maintainer will review within a few days.
- Address feedback by pushing new commits to the same branch.
- Once approved, the PR will be merged.

## Reporting Bugs

Open an issue with:

1. **Environment:**
   - OS and version (`cat /etc/os-release`).
   - zsh version (`zsh --version`).
   - Which router (`smart-pm` or `smart-py`).

2. **Reproduction steps:**
   - Exact commands you ran.
   - Expected behavior.
   - Actual behavior.

3. **Logs:**
   ```bash
   smart-pm-log 50 > /tmp/smart-pm-log.txt
   smart-py-log 50 > /tmp/smart-py-log.txt
   ```
   Attach the relevant file.

4. **Screenshots** (if visual).

## Suggesting Features

Open an issue with:

- **Use case:** what problem does it solve?
- **Proposed solution:** how would it work?
- **Alternatives:** what else have you considered?
- **Impact:** who benefits and how?

## Testing Guidelines

We don't have a formal test suite yet. If you want to contribute one, use [bats-core](https://github.com/bats-core/bats-core).

For manual testing:

```bash
# Test smart-pm routing
cd /tmp
mkdir test-pm && cd test-pm
pnpm init
npm install lodash           # should route to pnpm
smart-pm-log 3               # verify routing

# Test smart-py routing
cd /tmp
mkdir test-py && cd test-py
uv init .
pip install requests         # should route to uv
smart-py-log 3               # verify routing
```

## License

By contributing, you agree that your contributions will be licensed under the MIT License. See [LICENSE](LICENSE).

## Questions?

Open a discussion on GitHub or contact the maintainer.

Thanks for contributing!