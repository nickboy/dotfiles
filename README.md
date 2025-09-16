# 🏠 Nick's Dotfiles

[![Dotfiles CI](https://github.com/nickboy/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/nickboy/dotfiles/actions/workflows/ci.yml)

Personal dotfiles managed with [yadm](https://yadm.io/), containing
configurations for macOS development environment.

## 📦 What's Included

### Core Configurations

- **Shell**: Zsh configuration with zinit plugin manager
- **Editor**: Neovim (LazyVim) and Zed configurations
- **Terminal**: tmux and Ghostty configurations (with transparency and Claude Code integration)
- **Package Management**: Brewfile for Homebrew packages
- **Git**: Global git configuration
- **Tools**: ripgrep, bat configurations

### 🤖 Automation Scripts

- **Daily Maintenance**: Automated daily update scripts for Homebrew, zinit,
  bob, LazyVim, and cleanup
  - Automatic catch-up mechanism if laptop was off during scheduled time
  - Quick access via shell aliases: `mr` (run), `ms` (status), `ml` (logs)
- **Battery Monitoring**: Battery status monitoring utilities

## 🚀 Quick Start

### Prerequisites

- macOS (tested on macOS 14+)
- [Homebrew](https://brew.sh/) installed
- [yadm](https://yadm.io/) installed: `brew install yadm`

### Installation

1. **Clone the dotfiles repository:**

```bash
yadm clone https://github.com/nickboy/dotfiles.git
```

The bootstrap script will automatically run after cloning to:

- Set up configuration symlinks (e.g., Ghostty)
- Install Homebrew (if not present)
- Install packages from Brewfile
- Set up tmux and zinit plugin managers
- Configure daily maintenance automation

1. **Install remaining Homebrew packages (if bootstrap didn't complete):**

```bash
brew bundle --file=~/Brewfile
```

1. **Set up daily maintenance automation (optional):**

```bash
# Run the installation script
bash ~/install-daily-maintenance.sh

# Or manually control with:
~/daily-maintenance-control.sh status
```

## 📋 Daily Maintenance Automation

### Overview

Automates daily system maintenance tasks including:

- Homebrew formula updates (`brew upgrade`)
- Homebrew cask updates with greedy flag (`brew upgrade --cask --greedy`)
- Zinit plugin updates (`zinit update --all --quiet`)
- Bob (Neovim version manager) updates (`bob update`)
- LazyVim plugin updates (`nvim --headless '+Lazy! sync' +qa`)
- Homebrew cleanup (`brew cleanup --prune=all`) - removes old versions and
  clears cache

### Features

- ✅ Runs automatically at 9:00 AM daily via launchd
- ✅ **Catch-up mechanism**: Runs at login if missed scheduled time
- ✅ Comprehensive logging to `~/Library/Logs/`
- ✅ Error handling and status reporting
- ✅ Manual execution support with convenient aliases
- ✅ Easy enable/disable controls
- ✅ CI/CD pipeline with GitHub Actions
- ✅ Pre-commit hooks for validation
- ✅ Local test suite included
- ✅ No hardcoded paths - uses template system

### Daily Maintenance Installation

#### Automatic Installation

```bash
# Run the installer script
bash ~/install-daily-maintenance.sh
```

#### Manual Installation

```bash
# 1. Make scripts executable
chmod +x ~/daily-maintenance.sh
chmod +x ~/daily-maintenance-control.sh

# 2. Generate plist from template (if needed)
sed "s|{{HOME}}|$HOME|g" \
  ~/Library/LaunchAgents/com.daily-maintenance.plist.template \
  > ~/Library/LaunchAgents/com.daily-maintenance.plist

# 3. Load the LaunchAgent
launchctl load ~/Library/LaunchAgents/com.daily-maintenance.plist
```

### Usage

#### Quick Access Aliases (configured in .zshrc)

```bash
# Quick shortcuts for daily operations
mr  # Run maintenance manually (skips date check)
ms  # Check maintenance status
ml  # View maintenance logs
```

#### Full Control Commands

```bash
# Check status
~/daily-maintenance-control.sh status

# Run manually
~/daily-maintenance-control.sh run

# View logs
~/daily-maintenance-control.sh logs

# Stop automation
~/daily-maintenance-control.sh stop

# Start automation
~/daily-maintenance-control.sh start

# Edit the maintenance script
~/daily-maintenance-control.sh edit
```

### Configuration

#### Changing Schedule

Edit `~/Library/LaunchAgents/com.daily-maintenance.plist`:

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>9</integer>  <!-- Change hour (0-23) -->
    <key>Minute</key>
    <integer>0</integer>   <!-- Change minute (0-59) -->
</dict>
```

After editing, reload:

```bash
~/daily-maintenance-control.sh restart
```

#### Adding Commands

Edit `~/daily-maintenance.sh` and add your commands following the existing pattern:

```bash
if ! run_command "Description" your-command --args; then
    FAILED_COMMANDS+=("your-command")
fi
```

#### Sudo Access

If any commands require sudo, configure passwordless execution:

1. Edit sudoers: `sudo visudo -f /etc/sudoers.d/daily-maintenance`
2. Add: `yourusername ALL=(ALL) NOPASSWD: /path/to/command`

### Troubleshooting

#### Check if automation is running

```bash
launchctl list | grep daily-maintenance
```

#### View recent logs

```bash
tail -f ~/Library/Logs/daily-maintenance.log
```

#### View error logs

```bash
tail -f ~/Library/Logs/daily-maintenance-error.log
```

#### Reset automation

```bash
~/daily-maintenance-control.sh stop
~/daily-maintenance-control.sh start
```

### Uninstallation

To completely remove the automation (while keeping the scripts):

```bash
bash ~/uninstall-daily-maintenance.sh
```

Or manually:

```bash
# Stop and unload the automation
launchctl unload ~/Library/LaunchAgents/com.daily-maintenance.plist

# Optional: Remove log files
rm ~/Library/Logs/daily-maintenance*.log
```

## 👻 Ghostty Terminal Configuration

### Features

- **Transparency**: Background opacity (0.88) with blur effect for macOS liquid visuals
- **Shell Integration**: Enhanced shell integration for better Claude Code support
- **Smart Clipboard**: Protected paste with bracketed paste mode
- **Custom Keybinds**: Split panes with `Cmd+D` (down) and `Cmd+Shift+D` (right)
- **Theme**: Catppuccin Mocha with Hack Nerd Font

### Key Settings

- Transparent background with blur for modern macOS aesthetic
- Shell integration with working directory tracking (OSC 7)
- Enhanced clipboard features with paste protection
- Mouse support with focus-follows-mouse
- Link clicking enabled

Note: After modifying Ghostty config, restart the application for transparency
changes to take effect.

## 🖥️ Tmux Configuration

### Setup

TPM (Tmux Plugin Manager) is installed via Homebrew. After installing dotfiles:

1. Start tmux: `tmux new -s main`
2. Install plugins: Press `Ctrl-a + I` (capital I)
3. Plugins will be installed automatically

### Key Bindings

#### Prefix Key

- **Prefix**: `Ctrl-a` (remapped from default `Ctrl-b`)

#### Window & Pane Management

| Keybinding | Action |
|------------|--------|
| `Ctrl-a + \\` | Split window horizontally |
| `Ctrl-a + -` | Split window vertically |
| `Ctrl-a + h/j/k/l` | Resize panes (left/down/up/right) |
| `Ctrl-a + m` | Toggle pane zoom (maximize/restore) |
| `Ctrl-a + r` | Reload tmux configuration |

#### Navigation

| Keybinding | Action |
|------------|--------|
| `Ctrl-h/j/k/l` | Navigate between panes (vim-tmux-navigator) |
| `Ctrl-a + Ctrl-h` | Previous window |
| `Ctrl-a + Ctrl-l` | Next window |
| `Ctrl-a + <` | Swap window with previous |
| `Ctrl-a + >` | Swap window with next |
| `Ctrl-a + [number]` | Jump to window by number |

#### Copy Mode

| Keybinding | Action |
|------------|--------|
| `Ctrl-a + [` | Enter copy mode |
| `v` (in copy mode) | Begin selection |
| `y` (in copy mode) | Copy selection |
| `q` (in copy mode) | Exit copy mode |

## 🔧 Manual Updates

If you prefer to run updates manually:

```bash
# Homebrew updates
brew upgrade
brew upgrade --cask --greedy

# Zinit updates (in zsh)
zinit update --all

# Bob updates
bob update

# LazyVim updates (in Neovim)
nvim --headless '+Lazy! sync' +qa
```

## 📁 Repository Structure

```text
~/
├── .config/
│   ├── nvim/          # Neovim configuration (LazyVim)
│   ├── zed/           # Zed editor configuration
│   ├── ghostty/       # Ghostty terminal configuration
│   ├── bat/           # Bat themes
│   └── ripgrep/       # Ripgrep configuration
├── .local/
│   └── bin/           # User scripts
│       └── battery-status
├── Library/
│   └── LaunchAgents/  # macOS launch agents
│       ├── com.daily-maintenance.plist.template  # Template file
│       └── com.daily-maintenance.plist           # Generated (gitignored)
├── .gitconfig         # Git configuration
├── .tmux.conf         # Tmux configuration
├── .zshrc             # Zsh configuration
├── Brewfile           # Homebrew bundle
├── daily-maintenance.sh           # Main maintenance script
├── daily-maintenance-control.sh   # Control script
├── daily-maintenance-sudoers      # Sudoers template
├── install-daily-maintenance.sh   # Installation script
├── uninstall-daily-maintenance.sh # Uninstallation script
├── test-dotfiles.sh                # Local test suite
├── .github/
│   └── workflows/
│       └── ci.yml                  # CI/CD pipeline
├── .yadm/
│   └── hooks/
│       └── pre-commit              # Pre-commit validation
├── README.md                       # This file
└── CONTRIBUTING.md                 # Development guidelines
```

## 🔄 Updating Dotfiles

```bash
# Pull latest changes
yadm pull

# Check status
yadm status

# Add and commit changes
yadm add <file>
yadm commit -m "Description of changes"
yadm push
```

## 🧪 Testing & Linting

Run tests before committing:

```bash
# Run full test suite
bash ~/test-dotfiles.sh

# Install linters (using uv for speed)
brew install uv
uv tool install yamllint
uv tool install beautysh --with setuptools

# Run individual linters
yamllint -d relaxed .github/workflows/ci.yml
shellcheck *.sh  # If installed via brew
```

## 🤝 Contributing

Feel free to fork and submit pull requests. Some guidelines:

- Run `test-dotfiles.sh` before committing
- Use conventional commit messages
- Document any new scripts or configurations

## 📝 License

Personal dotfiles - use at your own risk. Feel free to take inspiration or
copy what you need.

## 🙏 Acknowledgments

- [yadm](https://yadm.io/) for dotfile management
- [LazyVim](https://www.lazyvim.org/) for Neovim configuration
- [zinit](https://github.com/zdharma-continuum/zinit) for Zsh plugin management
- [bob](https://github.com/MordechaiHadad/bob) for Neovim version management

---

Last updated: September 2025
