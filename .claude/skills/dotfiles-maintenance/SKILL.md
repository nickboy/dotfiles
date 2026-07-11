---
name: dotfiles-maintenance
description: |
  Use when user asks about "maintenance", "updates", "brew upgrade",
  mentions "daily-maintenance", "daily maintenance", "logs", "Brewfile",
  "brew bundle", or discusses system update automation.
version: 1.0.0
tools: Read, Glob, Grep, Bash
user-invocable: true
---

# Dotfiles Maintenance System

## What Daily Maintenance Does

Runs automatically at 9:00 AM via launchd (with catch-up if laptop was off):

1. `brew upgrade --yes` — Homebrew formula updates
2. `brew upgrade --cask --greedy-latest --yes` — Cask updates (`--yes`
   avoids Homebrew 6's confirmation prompt; also covers version-less casks;
   stale `*.upgrading` staging dirs are auto-cleaned first so a prior failed
   upgrade can't block the run)
3. `zinit update --all --quiet` — Zinit plugin updates
4. Oh-My-Zsh updates
5. `bob update` — Neovim version manager updates
6. `nvim --headless '+Lazy! sync' +qa` — LazyVim plugin sync
7. `nvim --headless '+TSUpdate' +qa` — Treesitter parser updates
8. `brew cleanup --prune=all` — Cleanup old versions and cache

## Quick Access Aliases

```bash
mr    # Run maintenance manually (skips date check)
ms    # Check maintenance status
ml    # View maintenance logs
```

## Control Script

```bash
~/daily-maintenance-control.sh status    # Check if automation is active
~/daily-maintenance-control.sh run       # Run manually
~/daily-maintenance-control.sh logs      # View logs
~/daily-maintenance-control.sh stop      # Disable automation
~/daily-maintenance-control.sh start     # Enable automation
~/daily-maintenance-control.sh restart   # Reload LaunchAgent
~/daily-maintenance-control.sh edit      # Edit the maintenance script
```

## Log Locations

- Main log: `~/Library/Logs/daily-maintenance.log`
- Error log: `~/Library/Logs/daily-maintenance-error.log`
- Both self-rotate to `.1` when they exceed 5 MB (copy+truncate at the
  start of each run)

## Concurrency & Robustness

- A lock at `~/.cache/dotfiles/daily-maintenance.lock` prevents the
  login catch-up racing the 9AM schedule; stale locks (dead PID or
  older than 6h) self-clear
- `brew upgrade` steps run under a 900s watchdog; exit 124 is logged
  as `TIMED OUT`, distinct from a real failure
- Shared helpers live in `~/daily-maintenance-lib.sh` (sourced by the
  install/uninstall/control scripts)
- launchctl uses `enable` + `bootstrap`/`bootout` (real exit codes) —
  the deprecated `load`/`unload` exit 0 even on failure, which once
  masked a disabled agent for a week

## LaunchAgent

- Template: `~/Library/LaunchAgents/com.daily-maintenance.plist##template`
  (yadm-native; `yadm alt` regenerates the real plist on every
  clone/pull, expanding `{{env.HOME}}`)
- Generated: `~/Library/LaunchAgents/com.daily-maintenance.plist` (gitignored)

### Changing the Schedule

Edit the plist and change Hour/Minute, then reload:

```bash
~/daily-maintenance-control.sh restart
```

## Managing Homebrew Packages

### Add a Package

1. Edit `~/Brewfile`
2. Run `brew bundle`

### Brewfile Structure

- `brew "package"` — CLI tools
- `cask "app"` — GUI applications
- `mas "App Name", id: 12345` — Mac App Store apps

## Adding Maintenance Commands

Edit `~/daily-maintenance.sh` following the existing pattern:

```bash
if ! run_command "Description" your-command --args; then
    FAILED_COMMANDS+=("your-command")
fi
```

## Manual Updates

```bash
brew upgrade --yes                         # Homebrew formulas
brew upgrade --cask --greedy-latest --yes  # Cask apps
zinit update --all                        # Zinit plugins
bob update                                # Neovim versions
nvim --headless '+Lazy! sync' +qa         # LazyVim plugins
nvim --headless '+TSUpdate' +qa           # Treesitter parsers
mise upgrade                              # Mise-managed tool versions
```

## Installation / Uninstallation

```bash
bash ~/install-daily-maintenance.sh       # Install automation
bash ~/uninstall-daily-maintenance.sh     # Remove automation
```
