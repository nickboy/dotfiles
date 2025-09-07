# Nick's Dotfiles Documentation for AI Assistants

This document provides comprehensive information about the dotfiles repository managed with [yadm](https://yadm.io/). It's designed to help AI assistants quickly understand the development environment and automation setup.

## Repository Information

- **Repository URL**: https://github.com/nickboy/dotfiles.git
- **Management Tool**: yadm (Yet Another Dotfiles Manager)
- **Primary OS**: macOS (Darwin 25.0.0)
- **Last Updated**: September 2025

## System Architecture Overview

### Core Technologies
- **Shell**: Zsh with Oh-My-Zsh framework and Zinit plugin manager
- **Terminal Multiplexer**: tmux with Tokyo Night theme
- **Primary Editors**: 
  - Neovim (LazyVim configuration)
  - Zed (with vim mode enabled)
- **Package Management**: Homebrew (Apple Silicon optimized at `/opt/homebrew`)
- **Version Control**: Git with delta for diffs
- **Prompt**: Starship

### Development Tools
- **Languages**: Python 3.13, Go, Rust, Julia, Node.js, Java (OpenJDK), Ruby
- **Linters/Formatters**: Ruff (Python), ShellCheck, Prettier, rust-analyzer
- **Search Tools**: ripgrep, fd, fzf with custom TokyoNight theme
- **File Navigation**: eza (modern ls), zoxide (smart cd), bat (cat with syntax highlighting)

## File Structure

```
~/
├── Configuration Files
│   ├── .zshrc                    # Zsh configuration with Zinit
│   ├── .gitconfig                # Git configuration with delta
│   ├── .tmux.conf                # Tmux configuration
│   └── Brewfile                  # Homebrew bundle definition
│
├── .config/
│   ├── nvim/                     # Neovim LazyVim configuration
│   │   ├── init.lua
│   │   ├── lazy-lock.json
│   │   └── lua/config/           # Neovim configs
│   ├── zed/                      # Zed editor settings
│   │   └── settings.json         # Comprehensive Zed configuration
│   ├── bat/                      # Bat themes
│   │   └── themes/tokyonight_night.tmTheme
│   └── ripgrep/                  # Ripgrep configuration
│       └── config                # Search exclusions and settings
│
├── .local/bin/                   # User scripts
│   └── battery-status            # Battery monitoring utility (Python)
│
├── Library/LaunchAgents/         # macOS automation
│   └── com.nickboy.daily-maintenance.plist
│
├── Automation Scripts
│   ├── daily-maintenance.sh      # Main update script
│   ├── daily-maintenance-control.sh # Control interface
│   ├── install-daily-maintenance.sh
│   └── uninstall-daily-maintenance.sh
│
├── Development & Testing
│   ├── test-dotfiles.sh          # Local test suite
│   ├── .github/workflows/ci.yml  # GitHub Actions CI/CD
│   └── .yadm/hooks/pre-commit    # Pre-commit validation
│
└── Documentation
    ├── README.md                  # User documentation
    ├── CONTRIBUTING.md            # Development guidelines
    └── CLAUDE.md                  # This file (AI assistant documentation)
```

## Key Configurations

### Shell Environment (.zshrc)

**Architecture**:
1. Early environment setup (PATH, compilation flags)
2. Oh-My-Zsh framework loading (minimal plugins)
3. Zinit plugin manager with lazy loading
4. Tool integrations (fzf, zoxide, starship)
5. Modern CLI aliases

**Key Features**:
- Smart plugin loading with Zinit for fast startup
- FZF with TokyoNight theme and preview windows
- Zoxide for intelligent directory navigation
- GitHub Copilot CLI integration
- Battery monitoring alias

**PATH Priority**:
1. `/opt/homebrew/bin` (Apple Silicon Homebrew)
2. `~/.local/bin` (user scripts)
3. `~/.cargo/bin` (Rust)
4. `~/.local/share/bob/nvim-bin` (Neovim versions)

### Editor Configuration

**Neovim**:
- Base: LazyVim distribution
- Location: `~/.config/nvim/`
- Version Manager: bob

**Zed** (`~/.config/zed/settings.json`):
- Vim mode enabled with relative line numbers
- Theme: One Dark
- Font: JetBrains Mono
- AI: Claude 3.5 Sonnet integration
- Format on save enabled
- Language-specific formatters configured
- Git inline blame enabled

### Automation System

**Daily Maintenance** (Runs at 9:00 AM):
1. Homebrew formula updates
2. Homebrew cask updates (greedy)
3. Zinit plugin updates
4. Bob (Neovim) updates
5. LazyVim plugin updates
6. Homebrew cleanup (removes old versions and cache)

**Control Commands**:
- `~/daily-maintenance-control.sh status` - Check automation status
- `~/daily-maintenance-control.sh run` - Run manually
- `~/daily-maintenance-control.sh logs` - View logs
- `~/daily-maintenance-control.sh stop/start` - Control automation

**Logs Location**:
- Main log: `~/Library/Logs/daily-maintenance.log`
- Error log: `~/Library/Logs/daily-maintenance-error.log`

### Git Configuration

- Pager: delta with syntax highlighting
- Merge conflict style: zdiff3
- Credential helper: Git Credential Manager
- User: Nick Liu (nickboy@users.noreply.github.com)

### Tmux Configuration

- Prefix: Ctrl-A (remapped from Ctrl-B)
- Splits: `\` horizontal, `-` vertical
- Vi mode enabled
- Mouse support enabled
- Plugins via TPM:
  - vim-tmux-navigator
  - tmux-resurrect (session persistence)
  - tmux-continuum (auto-save)
  - Tokyo Night theme

## Development Workflow

### Testing
Run before committing:
```bash
bash ~/test-dotfiles.sh
```

Tests include:
- Shell script syntax validation
- ShellCheck analysis
- Zsh configuration validation
- Plist validation
- Documentation checks

### CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`):
- **Lint checks**: ShellCheck, YAML, Markdown
- **Syntax validation**: Bash, Zsh
- **Security scanning**: Trivy, Trufflehog
- **Compatibility testing**: macOS latest and macOS 13
- **Documentation validation**

### Pre-commit Hook
Located at `.yadm/hooks/pre-commit`
Runs validation before allowing commits

## Installed Tools (Brewfile)

### CLI Tools
- **Search/Find**: ripgrep, fd, fzf, ffind, ast-grep
- **File Management**: eza, bat, chafa (image viewer), viu
- **Development**: git-delta, lazygit, neovim, tmux
- **Languages**: Python 3.13, Go, Rust, Julia, Node.js, Java, Perl, Ruby
- **Package Managers**: Composer (PHP), LuaRocks, pipx, cargo
- **Linters**: ruff, pyright, shellcheck
- **Utilities**: thefuck, tlrc, wget, yadm, zoxide

### GUI Applications (Casks)
- **Password**: 1Password + CLI
- **Browsers**: Arc
- **Development**: Ghostty, Warp (terminals)
- **Media**: IINA, Spotify
- **Utilities**: BetterDisplay, Raycast, Rectangle Pro, SoundSource
- **VPN**: NordVPN, Surfshark
- **Fonts**: Hack Nerd Font

## Custom Scripts

### battery-status
Python script at `~/.local/bin/battery-status`
- Shows battery charging/discharging wattage
- Displays voltage and amperage
- Usage: `battery` or `battery -v` for verbose

## Important Notes for AI Assistants

### When Making Changes

1. **Always respect existing patterns**:
   - Check neighboring files for conventions
   - Use existing libraries/frameworks
   - Follow the established code style

2. **Path considerations**:
   - Homebrew is at `/opt/homebrew` (Apple Silicon)
   - Use `$HOME` instead of hardcoded user paths
   - Scripts should be executable (`chmod +x`)

3. **Testing requirements**:
   - Run `bash ~/test-dotfiles.sh` before committing
   - Check syntax with appropriate tools
   - Ensure LaunchAgent plists are valid

4. **Zsh-specific notes**:
   - Zinit manages most plugins
   - Oh-My-Zsh provides the framework
   - Don't duplicate plugin loading

5. **Updates and maintenance**:
   - Daily automation handles most updates
   - Manual control via `daily-maintenance-control.sh`
   - Logs are in `~/Library/Logs/`

### Common Tasks

**Run linters before committing**:
```bash
# Install linters with uv (fast Python package manager)
brew install uv  # If not installed
uv tool install yamllint
uv tool install beautysh --with setuptools

# Run YAML lint
yamllint -d relaxed .github/workflows/ci.yml

# Run shell script lint (if shellcheck is installed)
shellcheck *.sh

# Run test suite
bash ~/test-dotfiles.sh
```

**Add a new Homebrew package**:
1. Edit `~/Brewfile`
2. Run `brew bundle`

**Modify daily maintenance**:
1. Edit `~/daily-maintenance.sh`
2. Test with `~/daily-maintenance-control.sh run`
3. Check logs for errors

**Update Neovim configuration**:
1. Edit files in `~/.config/nvim/`
2. Restart Neovim to apply changes

**Change Zed settings**:
1. Edit `~/.config/zed/settings.json`
2. Changes apply automatically

**Manage dotfiles with yadm**:
```bash
yadm status           # Check status
yadm add <file>       # Track new file
yadm commit -m "msg"  # Commit changes
yadm push            # Push to GitHub
```

## Environment Details

- **Working Directory**: /Users/nickboy
- **Platform**: macOS (Darwin 25.0.0)
- **Shell**: Zsh with extensive customization
- **Python**: 3.13 via Homebrew
- **Node**: Latest via Homebrew
- **Rust**: Managed via rustup

## Security Considerations

- No secrets in dotfiles (use `.gitignore`)
- Git credentials managed by Git Credential Manager
- Edit predictions disabled for sensitive files in Zed
- Telemetry disabled in Zed configuration

## Contact & Support

- Repository: https://github.com/nickboy/dotfiles
- Issues: Report at repository issues page
- CI Status: Check GitHub Actions tab

---

*This documentation is specifically designed for AI assistants to quickly understand and work with this dotfiles setup. Always verify current state with `yadm status` and check actual file contents when making modifications.*