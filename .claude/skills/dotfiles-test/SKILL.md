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

1. **Shell Validation** — ShellCheck and syntax checking
2. **macOS Integration** — Tests on multiple macOS versions
3. **Security Scanning** — Trivy and Trufflehog for secrets/vulnerabilities
4. **Documentation** — Validates README and markdown files
5. **Compatibility Matrix** — Tests on Ubuntu and macOS 12/13/14

## Pre-commit Hook

Located at `~/.yadm/hooks/pre-commit`. Runs validation automatically before
each `yadm commit`. To bypass in emergencies:

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
