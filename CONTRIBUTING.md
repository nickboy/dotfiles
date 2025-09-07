# Contributing to Dotfiles

## 🧪 Testing Requirements

All changes must pass automated testing before merging. We use a comprehensive CI/CD pipeline to ensure quality.

### Local Testing

Before pushing changes, run the local test suite:

```bash
./test-dotfiles.sh
```

This will check:
- Shell script syntax
- Executable permissions
- Plist validation
- ShellCheck analysis (if installed)
- Documentation completeness
- Common issues

### Pre-commit Hook

A pre-commit hook is automatically installed that runs tests before each commit. To bypass in emergencies:

```bash
yadm commit --no-verify -m "Emergency fix"
```

### GitHub Actions CI

Every PR triggers automated testing:

1. **Shell Validation** - ShellCheck and syntax checking
2. **macOS Integration** - Tests on multiple macOS versions
3. **Security Scanning** - Checks for secrets and vulnerabilities
4. **Documentation** - Validates README and markdown files
5. **Compatibility Matrix** - Tests on Ubuntu and macOS 12/13/14

## 🔒 Recommended Branch Protection Rules

To set up branch protection for `main` or `master`:

1. Go to Settings → Branches in your GitHub repository
2. Add a branch protection rule for `main` (or `master`)
3. Enable these settings:

### Required Status Checks
- ✅ **Require status checks to pass before merging**
  - Shell Script Validation
  - Bash Syntax Check
  - macOS Integration Tests
  - Documentation Validation

### PR Requirements
- ✅ **Require pull request reviews before merging** (1 review)
- ✅ **Dismiss stale pull request approvals when new commits are pushed**
- ✅ **Require review from CODEOWNERS** (optional)

### Additional Protection
- ✅ **Require branches to be up to date before merging**
- ✅ **Require conversation resolution before merging**
- ✅ **Include administrators** (optional - disable for emergency fixes)

## 📝 Commit Message Convention

Use conventional commits for clear history:

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `test:` Test additions or changes
- `refactor:` Code refactoring
- `style:` Formatting changes
- `chore:` Maintenance tasks

Example:
```bash
yadm commit -m "feat: Add tmux session management script"
```

## 🚀 Pull Request Process

1. **Create a feature branch:**
   ```bash
   yadm checkout -b feature/your-feature-name
   ```

2. **Make your changes and test locally:**
   ```bash
   ./test-dotfiles.sh
   ```

3. **Commit with descriptive messages:**
   ```bash
   yadm add .
   yadm commit -m "feat: Description of your change"
   ```

4. **Push to GitHub:**
   ```bash
   yadm push -u origin feature/your-feature-name
   ```

5. **Create a Pull Request:**
   - Go to https://github.com/nickboy/dotfiles
   - Click "Pull requests" → "New pull request"
   - Select your branch
   - Fill in the PR template (if available)
   - Wait for CI checks to pass
   - Request review if needed

## 🐛 Debugging CI Failures

If CI fails on your PR:

1. **Check the Actions tab** for detailed logs
2. **Run failed tests locally:**
   ```bash
   # For ShellCheck issues
   shellcheck -S warning your-script.sh
   
   # For syntax issues
   bash -n your-script.sh
   
   # For plist issues (macOS)
   plutil -lint your.plist
   ```

3. **Common fixes:**
   - ShellCheck warnings: Follow the wiki links in error messages
   - Syntax errors: Check for missing quotes, brackets, or semicolons
   - Plist errors: Validate XML structure

## 🔧 Installing Development Tools

### macOS
```bash
# Install ShellCheck for better validation
brew install shellcheck

# Install yamllint for YAML validation
brew install yamllint
```

### Linux
```bash
# Ubuntu/Debian
sudo apt-get install shellcheck yamllint

# Fedora
sudo dnf install ShellCheck yamllint
```

## 📊 CI Status Badge

Add this to your README to show CI status:

```markdown
[![Dotfiles CI](https://github.com/nickboy/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/nickboy/dotfiles/actions/workflows/ci.yml)
```

## 🆘 Getting Help

- Check existing issues and PRs
- Review the CI logs for specific error messages
- Ask questions in PR comments
- Consult ShellCheck wiki: https://www.shellcheck.net/wiki/

---

Thank you for contributing! Your improvements help make these dotfiles better for everyone.
