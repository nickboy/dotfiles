---
name: dotfiles-test
description: |
  Use when user asks to "test", "lint", "validate", "run checks",
  mentions "CI", "shellcheck", "markdownlint", "test-dotfiles",
  or discusses testing and validation for this dotfiles repository.
version: 1.0.0
tools: Read, Glob, Grep, Bash
user-invocable: true
---

# Dotfiles Testing & Validation

## Primary Test Command

```bash
bash ~/test-dotfiles.sh
```

This runs all checks: shell syntax, executable permissions, plist validation,
ShellCheck analysis, documentation completeness, and common issues.

## Individual Linters

### Shell Scripts

```bash
shellcheck *.sh                          # Lint all shell scripts
shellcheck -S warning your-script.sh     # With severity filter
bash -n your-script.sh                   # Syntax check only
```

### Markdown

```bash
npx markdownlint-cli '**/*.md' --ignore node_modules
npx markdownlint-cli README.md CLAUDE.md   # Specific files
```

### YAML

```bash
yamllint -d relaxed .github/workflows/ci.yml
```

### Plist (macOS)

```bash
plutil -lint ~/Library/LaunchAgents/com.daily-maintenance.plist
```

## Installing Linters

```bash
# Python-based linters (fast install via uv)
brew install uv
uv tool install yamllint
uv tool install beautysh --with setuptools

# Node-based linters
npm install -g markdownlint-cli

# Shell linter
brew install shellcheck
```

## CI/CD Pipeline

GitHub Actions workflow at `.github/workflows/ci.yml` runs on every PR:

1. **Comprehensive Lint** (ubuntu) — shebang-detected shellcheck +
   bash -n over all tracked scripts, yamllint, **blocking** markdownlint,
   JSON/TOML/Lua/plist/Brewfile validation
2. **macOS Integration + Test Suite** — zsh/beautysh checks, Zellij KDL
   validation, plutil on the plist template, `test-bootstrap.sh`, and
   the full `test-dotfiles.sh` run
3. **Security Scanning** (ubuntu) — Trivy and Trufflehog
4. **Documentation Links** (ubuntu) — README link check

## Pre-commit Hook

Located at `~/.config/yadm/hooks/pre_commit` (yadm 3.x reads
`$YADM_DIR/hooks/pre_<command>`; the legacy `~/.yadm/hooks/pre-commit`
path is never executed). Runs the full test suite before each
`yadm commit`. Note: the hook only intercepts `yadm commit` — direct
`GIT_DIR=… git commit` bypasses it; CI is the blocking second layer.
To bypass in emergencies:

```bash
yadm commit --no-verify -m "Emergency fix"
```

## Debugging CI Failures

1. Check the Actions tab on GitHub for detailed logs
2. Run the specific failing check locally (see individual linters above)
3. Common fixes:
   - ShellCheck: Follow wiki links in error messages
   - Syntax errors: Check for missing quotes, brackets, semicolons
   - Plist errors: Validate XML structure with `plutil -lint`
