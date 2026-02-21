# 🏠 Nick's Dotfiles

[![Dotfiles CI](https://github.com/nickboy/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/nickboy/dotfiles/actions/workflows/ci.yml)

> **Language**: English | [繁體中文](README.zh-TW.md)

Personal dotfiles managed with [yadm](https://yadm.io/), containing
configurations for macOS development environment.

## 📦 What's Included

### Core Configurations

- **Shell**: Zsh configuration with zinit plugin manager and Oh-My-Zsh plugins
- **Editor**: Neovim (LazyVim) and Zed configurations
- **Terminal**: tmux with sesh session manager, Ghostty and Kitty configs
- **Package Management**: Brewfile for Homebrew packages
- **Git**: Global git configuration
- **Modern CLI Tools**: ripgrep, bat, eza, dust, duf, btop, yazi, and more
- **Version Management**: mise (polyglot dev tool manager for node, python, etc.)
- **Completions**: Carapace (universal command completions)
- **SSH**: Modular `config.d/` setup with multiplexing, keepalive, and agent forwarding
- **Claude Code**: Integrated statusline with ccusage for cost tracking,
  desktop notifications via OSC 9/777 (works in Ghostty, Neovim, and SSH),
  claudecode.nvim with 40% split width and diff-in-new-tab workflow
- **Git Diff View**: diffview.nvim for side-by-side diff review and file
  history browsing directly in Neovim
- **Neovim UI Enhancements**: treesitter-context (sticky function header),
  illuminate (highlight symbol under cursor), inc-rename (live rename preview),
  custom ASCII dashboard, and smooth scroll animation

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
- Oh-My-Zsh updates
- Bob (Neovim version manager) updates (`bob update`)
- LazyVim plugin updates (`nvim --headless '+Lazy! sync' +qa`)
- Treesitter parser updates (`nvim --headless '+TSUpdate' +qa`)
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

### Ghostty Features

- **Transparency**: Background opacity (0.75) with blur for macOS
  visuals
- **Shell Integration**: Enhanced shell integration with `sudo`,
  `title`, and `path` features (cursor feature disabled to avoid
  conflict with custom GLSL cursor shaders)
- **Smart Clipboard**: Protected paste with bracketed paste mode
- **Option as Alt**: Left Option key acts as Alt for word movement
  (`Alt+B/F/D`)
- **Window Persistence**: Always restores window layout across restarts
  (`window-save-state = always`)
- **Cell Width Tuning**: `adjust-cell-width = 1%` for Nerd Font icon
  alignment
- **Prompt Navigation**: `Cmd+Up/Down` to jump between shell
  prompts in scrollback
- **Split Zoom**: `Cmd+Shift+Enter` to maximize/restore a split
  pane
- **Resize Overlay**: Shows terminal dimensions while resizing
- **Link Previews**: Hover over URLs to see previews
- **Auto-Update**: Notifications when Ghostty updates are available
- **Bell Notifications**: Dock bounce and bell emoji in tab title
  for permission requests
- **Desktop Notifications**: OSC 9/777 banner notifications via
  `claude-notify` hook (works in Ghostty direct, Neovim terminal,
  and SSH remote sessions)
- **Cursor Shaders**: Animated cursor effects (`cursor_slash.glsl`,
  `cursor_smear.glsl`)
- **Config Reload**: `Cmd+Shift+,` to reload config without restart
- **Quick Terminal**: `Cmd+`` global hotkey for Quake-style dropdown
  terminal (70% height, auto-hides on focus loss)
- **Unfocused Split Dimming**: Inactive split panes dim to 85% opacity
- **Window Subtitle**: Shows current working directory below tab bar
- **Mouse Scroll Multiplier**: 2x scroll speed for faster navigation
- **Cursor Click-to-Move**: `Option+Click` to reposition cursor in
  long commands
- **Tab-Only Titlebar**: `macos-titlebar-style = tabs` removes traffic
  lights, keeps tab bar
- **Theme**: Catppuccin Mocha with Hack Nerd Font

### Key Settings

- Transparent background with blur for modern macOS aesthetic
- Balanced padding with extended cell background colors for a
  seamless look
- Shell integration with `sudo`, `title`, `path` (no `cursor` — shaders
  handle cursor rendering)
- Enhanced clipboard features with paste protection
- Mouse support with focus-follows-mouse
- Link clicking and hover previews enabled

Note: Shaders are located in `~/.config/ghostty/shaders/` and
symlinked via bootstrap. Use `Cmd+Shift+,` to reload config after
changes.

### Claude Code Notifications (SSH Remote)

For desktop notifications when running Claude Code on a remote
Linux machine via SSH, copy the notification script and hook config:

```bash
scp ~/.local/bin/claude-notify remote:~/.local/bin/
scp ~/.claude/settings.json remote:~/.claude/
```

OSC 9/777 escape sequences travel back through SSH to Ghostty,
which displays macOS banner notifications. No additional tools
(e.g., `terminal-notifier`) need to be installed on the remote
machine. Ensure Ghostty is in your Focus mode allowed apps list.

## 🔐 SSH Configuration

### Modular Setup

SSH configuration uses `Include config.d/*` to separate shared
defaults from machine-specific settings. This allows the same
dotfiles to work on both personal and work laptops without conflicts.

```text
~/.ssh/
├── config              # Include directive + machine-specific entries
├── config.d/
│   └── 00-defaults.conf  # Shared defaults (tracked by yadm)
└── sockets/            # ControlMaster socket directory
```

### Shared Defaults (`00-defaults.conf`)

- **Connection Multiplexing**: `ControlMaster auto` with 10-minute
  socket persistence — second SSH to the same host is instant
- **Keepalive**: Send every 30s, tolerate 3 missed (90s detection)
- **Agent Forwarding**: `ForwardAgent yes` for `git push` on remote
  using local SSH keys
- **Compression**: Enabled for all connections
- **TERM Handling**: `SetEnv TERM=xterm-256color` for remote machines
  lacking `xterm-ghostty` terminfo

### Work Laptop Setup

When pulling these dotfiles on a work laptop that already has
corporate SSH configuration:

1. **Back up existing SSH config** before pulling:

   ```bash
   cp ~/.ssh/config ~/.ssh/config.bak
   ```

2. **Pull the dotfiles**:

   ```bash
   yadm pull
   ```

3. **Merge corporate entries** — add them below the `Include` line in
   `~/.ssh/config`:

   ```ssh-config
   # Load modular configs (YADM-managed defaults + any machine-specific overrides)
   Include config.d/*

   # Corporate SSH entries (from your previous config)
   Host bastion.corp.example.com
       User corporate-username
       IdentityFile ~/.ssh/id_corporate
       ProxyJump none

   Host *.internal.corp.example.com
       User corporate-username
       ProxyJump bastion.corp.example.com
   ```

   Alternatively, place corporate config in a separate file like
   `~/.ssh/config.d/10-work.conf` (add to `.gitignore` if not
   sharing via yadm).

4. **Create required directories** (if not present):

   ```bash
   mkdir -p ~/.ssh/sockets ~/.ssh/config.d && chmod 700 ~/.ssh/sockets
   ```

**Note**: SSH uses "first match wins" — specific `Host` entries
(corporate config) always take precedence over `Host *` defaults in
`00-defaults.conf`. Your corporate settings will not be overridden.

## 🧠 Neovim Claude Code Integration

### claudecode.nvim Configuration

Custom settings for the LazyVim claudecode extra
(`~/.config/nvim/lua/plugins/claudecode.lua`):

| Setting | Value | Description |
| --- | --- | --- |
| `split_width_percentage` | `0.40` | 40% width (default 30%) for more room |
| `git_repo_cwd` | `true` | Start Claude at git repo root |
| `show_native_term_exit_tip` | `false` | Suppress exit tip |
| `diff_opts.open_in_new_tab` | `true` | Diffs open in new tab |
| `diff_opts.keep_terminal_focus` | `true` | Stay in Claude after diff |
| `diff_opts.hide_terminal_in_new_tab` | `true` | Full-screen diff view |
| `focus_after_send` | `true` | Focus Claude after sending selection |

### Claude Code Keymaps

| Keymap | Mode | Action |
| --- | --- | --- |
| `<leader>ac` | n | Toggle Claude terminal |
| `<leader>af` | n | Focus Claude terminal |
| `<leader>ar` | n | Resume Claude (`--resume`) |
| `<leader>aC` | n | Continue Claude (`--continue`) |
| `<leader>ab` | n | Add current buffer to context |
| `<leader>as` | v | Send visual selection to Claude |
| `<leader>aa` | n | Accept diff |
| `<leader>ad` | n | Deny diff |
| `<leader>am` | n | Select Claude model (Opus/Sonnet/Haiku) |
| `<Esc><Esc>` | t | Exit terminal mode (scroll Claude output) |

### Diffview (Git Diff Viewer)

Side-by-side git diff viewer (`~/.config/nvim/lua/plugins/diffview.lua`):

| Keymap | Action |
| --- | --- |
| `<leader>gd` | Open diff view (all changed files) |
| `<leader>gf` | Current file history |
| `<leader>gF` | Full branch/repo history |
| `q` | Close diff view |

### OSC52 Clipboard (Remote Sessions)

Neovim 0.10+ has built-in OSC52 clipboard support. The configuration
(`~/.config/nvim/lua/plugins/osc52.lua`) automatically activates when
`SSH_CONNECTION` or `TMUX` is detected, enabling yank-to-local-clipboard
over SSH without any extra tools.

The full clipboard chain: Neovim OSC52 → tmux passthrough (`all`) →
SSH → Ghostty (`clipboard-write = allow`) → macOS clipboard.

## 🌐 Remote Development

### Shell TERM Handling

The shell automatically sets `TERM` based on environment:

- **Local (Ghostty)**: `xterm-ghostty` — enables Ghostty-specific
  capabilities (extended keyboard protocol, better rendering)
- **Remote (SSH)**: `xterm-256color` — compatible with all servers

### Remote Work Helpers

Available in SSH sessions (defined in `~/.zshrc`):

```bash
# OSC52 clipboard — copies to local macOS clipboard over SSH
echo "text" | clip
clip "some text"

# pbcopy alias — works transparently on remote machines
echo "text" | pbcopy

# Quick SSH + tmux attach-or-create
ssht hostname              # Attach to "main" session
ssht hostname mysession    # Attach to named session
```

### Nested tmux Sessions

When SSH-ing into a remote machine that also runs tmux, both local
and remote tmux share the same prefix (`Ctrl-a`). Press **F12** to
toggle:

- **F12 once**: Disables outer tmux (status bar turns grey), all keys
  pass to inner (remote) tmux
- **F12 again**: Re-enables outer tmux, restores normal operation

## 🐱 Kitty Terminal Configuration

### Kitty Features

- **Monaspace Fonts**: GitHub's variable font family with Radon italic style
- **Ligatures**: Full OpenType support with texture healing and coding ligatures
- **Cursor Trail**: Animated cursor trail effect (Kitty 0.37+ exclusive)
- **Transparency**: Background opacity (0.75) with blur, matching Ghostty
- **Kittens**: Built-in tools for images, hints, diffs, themes, and more
- **Remote Control**: Scriptable via unix socket for automation
- **Layouts**: 7 built-in layouts (tall, stack, fat, grid, splits, etc.)
- **Theme**: Catppuccin Mocha (same as Ghostty)

### Kitty Shortcuts

| Keybinding | Action |
| --- | --- |
| `Cmd+D` | Horizontal split |
| `Cmd+Shift+D` | Vertical split |
| `Ctrl+h/j/k/l` | Vim-style pane navigation |
| `Cmd+Arrow keys` | Pane navigation |
| `Ctrl+Shift+L` | Cycle layouts |
| `Cmd+Shift+,` | Reload config |
| `Ctrl+Shift+I` | Display images (icat) |
| `Ctrl+Shift+E` | Hints mode (URLs, paths) |
| `Ctrl+Shift+U` | Unicode input |
| `Ctrl+Shift+H` | Open scrollback in nvim |

### Kittens (Built-in Tools)

- **icat**: Display images directly in terminal
- **hints**: Select URLs, paths, words with keyboard
- **diff**: Side-by-side diff with syntax highlighting
- **themes**: Preview and switch themes interactively
- **choose-fonts**: Preview fonts with variable font support
- **broadcast**: Type in all windows simultaneously
- **unicode_input**: Insert unicode characters by name

### Third-Party Integrations

Works seamlessly with image-capable tools:

- **yazi/ranger**: File managers with image preview
- **timg**: Image and video viewer
- **mpv**: Video player (`mpv --vo=kitty video.mp4`)
- **awrit**: Chromium-based terminal browser
- **presenterm**: Markdown presentations with images

## 🖥️ Tmux Configuration

### Setup

TPM (Tmux Plugin Manager) is installed via Homebrew. After installing dotfiles:

1. Start tmux: `tmux new -s main`
2. Install plugins: Press `Ctrl-a + I` (capital I)
3. Plugins will be installed automatically

### Configuration Features

- **Truecolor + Ghostty RGB**: Terminal overrides for full 24-bit
  color in Ghostty and xterm-256color
- **Transparency Passthrough**: Ghostty background opacity and blur
  visible through tmux panes
- **OSC52 Clipboard**: System clipboard integration via `set-clipboard on`
- **DCS Passthrough**: Full passthrough (`all`) enables image protocols,
  shell integration, and nested OSC52 clipboard through tmux
- **Undercurl Support**: Colored wavy underlines for Neovim LSP diagnostics
- **Window/Pane Numbering**: Starts at 1 instead of 0 for easier keyboard access
- **Mouse Support**: Enabled for pane selection and scrolling
- **Vi Mode**: Vi-style key bindings for copy mode
- **Auto-renumber**: Windows automatically renumber when one is closed
- **Theme**: Catppuccin Mocha theme with custom status bar
- **Session Persistence**: Auto-saves and restores sessions via tmux-resurrect/continuum
- **Current-Path Splits**: New splits and windows open in the current
  working directory
- **Nested Session Toggle**: F12 disables outer tmux for SSH remote
  tmux sessions (status bar changes color to indicate)
- **tmux-yank**: Consistent copy behavior with OSC52 fallback for
  remote sessions

### Key Bindings

#### Prefix Key

- **Prefix**: `Ctrl-a` (remapped from default `Ctrl-b`)

#### Window Management

| Keybinding | Action |
| --- | --- |
| `Ctrl-a + 1-9` | Switch to window by number (1-indexed) |
| `Ctrl-a + n` | Next window |
| `Ctrl-a + p` | Previous window |
| `Ctrl-a + l` | Last active window |
| `Ctrl-a + w` | Choose window from list |
| `Ctrl-a + c` | Create new window |
| `Ctrl-a + ,` | Rename current window |
| `Ctrl-a + &` | Kill current window |
| `Ctrl-a + T` | Open sesh session switcher (custom) |

#### Pane Management

| Keybinding | Action |
| --- | --- |
| `Ctrl-a + \\` | Split horizontally (current directory) |
| `Ctrl-a + -` | Split vertically (current directory) |
| `Ctrl-a + c` | New window (current directory) |
| `Ctrl-a + h/j/k/l` | Navigate between panes (vim-style) |
| `Ctrl-a + H/J/K/L` | Resize pane (repeatable, 5 cells) |
| `Ctrl-a + <` | Swap window left (repeatable) |
| `Ctrl-a + >` | Swap window right (repeatable) |
| `Ctrl-a + x` | Kill current pane |
| `Ctrl-a + z` | Toggle pane zoom (maximize/restore) |
| `Ctrl-a + Space` | Toggle between pane layouts |
| `Ctrl-a + {` | Move pane left |
| `Ctrl-a + }` | Move pane right |
| `Ctrl-a + r` | Reload tmux configuration |
| `F12` | Toggle nested tmux (for SSH sessions) |

#### Seamless Navigation

| Keybinding | Action |
| --- | --- |
| `Ctrl-h/j/k/l` | Navigate between tmux panes and vim splits seamlessly |

#### Session Management (sesh)

Sesh is a smart tmux session manager integrated with zoxide.

**Shell Commands:**

| Command | Description |
| --- | --- |
| `s` | Interactive session picker with fzf preview |
| `s myproject` | Connect to existing session or create from path |
| `sn` | Create session named after current directory |
| `sl` | List all sessions with icons |
| `sls` | List only tmux sessions |

**Inside tmux:**

| Keybinding | Action |
| --- | --- |
| `Ctrl-a + T` | Open advanced sesh session switcher |

**Session switcher controls** (when using `Ctrl-a + T`):

- `Tab/Shift-Tab`: Navigate sessions
- `Enter`: Connect to selected
- `Ctrl-a`: Show all sessions
- `Ctrl-t`: Show tmux sessions only
- `Ctrl-g`: Show config sessions
- `Ctrl-x`: Show zoxide directories
- `Ctrl-f`: Find directories
- `Ctrl-d`: Kill selected session

**Workflow examples:**

```bash
# Start your day - pick a project
s

# Quick project switch inside tmux
Ctrl-a + T

# New project session
cd ~/projects/my-app && sn

# Clone repo and create session
sesh clone https://github.com/user/repo
```

#### Copy Mode

| Keybinding | Action |
| --- | --- |
| `Ctrl-a + [` | Enter copy mode |
| `v` (in copy mode) | Begin selection |
| `y` (in copy mode) | Copy selection |
| `q` (in copy mode) | Exit copy mode |

## 🛠️ Modern CLI Tools

Modern Rust-based replacements for traditional Unix tools:

| Traditional | Modern Tool | Description | Alias |
| --- | --- | --- | --- |
| `ls` | **eza** | Modern ls with git integration | `ls`, `ll`, `lt` |
| `cat` | **bat** | Cat with syntax highlighting | `cat` |
| `grep` | **ripgrep** | Faster grep with smart defaults | `rg` |
| `find` | **fd** | Simpler, faster find | `fd` |
| `du` | **dust** | Intuitive disk usage with tree view | `du` |
| `df` | **duf** | Pretty disk usage with colors | `df` |
| `top`/`htop` | **btop** | Beautiful resource monitor | `top`, `htop` |
| `dig` | **doggo** | User-friendly DNS client | `dog` |
| `sed` | **sd** | Simpler find & replace | `replace` |
| `ps` | **procs** | Modern process viewer | `ps` |
| `cut` | **choose** | Human-friendly field selection | `choose` |
| `time` | **hyperfine** | Command benchmarking tool | `bench` |
| `hexdump` | **hexyl** | Colored hex viewer | `hex` |
| `curl` | **xh** | Fast HTTP client | `http`, `https` |
| - | **tokei** | Code statistics tool | `count` |
| `man` | **tlrc** | Quick command examples | `help`, `cheat` |
| - | **yazi** | Blazing fast file manager | `y` |
| - | **serpl** | TUI search & replace | `sr` |
| - | **television** | Fuzzy finder with previews | `tv` |
| - | **glow** | Terminal markdown renderer | `md` |
| `git` | **jujutsu** | Git-compatible VCS | `jj` |
| `nvm`/`pyenv` | **mise** | Polyglot version manager | `mise` |

### Shell Enhancements

- **z-shell/zsh-eza**: Smart eza aliases with git status, icons, and grouping
- **Atuin**: Enhanced shell history with SQLite storage, fuzzy search, and syntax
  highlighting
- **Oh-My-Zsh Libraries** (via Zinit):
  - `directories` - Directory navigation (`..`, `...`, `d`, 1-9 stack, AUTO_CD)
  - `history` - Enhanced history with timestamps (`HIST_STAMPS`)
  - `misc` - Utility functions (env, pgrep, confirm_wrapper)
- **Oh-My-Zsh Plugins** (via Zinit):
  - `common-aliases` - Global pipe aliases (H/T/G/L/NUL)
  - `colored-man-pages` - Syntax-highlighted man pages
  - `web-search` - Search from terminal (google, github, stackoverflow)
  - `sudo` - Press ESC ESC to add sudo to previous command
  - `extract` - Universal archive extraction
  - `copypath` / `copyfile` - Quick clipboard operations
  - `jsontools` - JSON formatting and validation
  - `encode64` - Base64 encoding/decoding

### Directory Navigation

```bash
# Quick navigation (directories.zsh)
..              # cd ..
...             # cd ../..
....            # cd ../../..
d               # Show last 10 directories with numbers
1               # Jump to 1st previous directory
2               # Jump to 2nd previous directory (up to 9)
~/Projects      # Direct path entry (AUTO_CD enabled)

# Smart navigation (zoxide)
z project       # Jump to most-frecent 'project' directory
cd mydir        # Uses zoxide under the hood
```

### Global Pipe Aliases (common-aliases)

```bash
# Pipe shortcuts - append to any command
cat file.txt G "error"    # | grep "error"
cat file.txt H            # | head
cat file.txt T            # | tail
cat file.txt L            # | less
command NUL               # > /dev/null 2>&1
```

### Web Search

```bash
# Search engines from terminal (web-search plugin)
google "zsh tutorial"
github "zinit plugin"
stackoverflow "bash vs zsh"
ddg "privacy search"        # DuckDuckGo
youtube "vim tips"
```

### Shell History (Atuin)

Atuin replaces traditional shell history with a SQLite database, providing
syntax highlighting, fuzzy search, and rich metadata.

Features: workspace-aware filtering (up-arrow shows repo-scoped history),
vi keymap mode, compact style, and automatic secrets filtering.

```bash
# Interactive history search (Ctrl+R)
# - Fuzzy search with syntax highlighting
# - Filter by: host, session, directory, workspace, or global
# - Press Ctrl+R again to cycle filter modes
# - Up-arrow filters by current git repo (workspace mode)

# Statistics
atuin stats              # Show command usage statistics

# Search commands
atuin search "git"       # Search history for git commands
atuin search --cwd .     # Search only in current directory
```

**Key bindings in search UI:**

| Key | Action |
| --- | --- |
| `Ctrl+R` | Open search / cycle filter mode |
| `↑/↓` | Navigate results |
| `Enter` | Execute selected command |
| `Tab` | Insert command to edit |
| `Esc` | Exit search |

### FZF-Powered Git Helpers

```bash
# Fuzzy branch checkout (sorted by most recent)
gb

# Fuzzy checkout from git log
gl

# Ripgrep + FZF interactive code search (Enter opens in nvim)
rgf "pattern"
```

### Usage Examples

```bash
# Modern file listing with git status
ls              # eza with icons, git status, directories first
ll              # Long format with headers
lt              # Grid view with details
tree            # Tree view

# Disk analysis
dust            # Visual tree of disk usage
duf             # Pretty disk space report

# System monitoring
btop            # Beautiful resource monitor

# DNS queries
dog google.com  # Colorful DNS lookup

# HTTP requests
http GET https://api.example.com/users
xh POST https://api.example.com/data key=value

# Benchmarking
bench 'command1' 'command2'  # Compare performance

# Code statistics
count .         # Count lines of code by language

# Quick help
help tar        # Show tar examples
cheat docker    # Docker command examples

# File management (yazi)
y               # Open yazi, cd to last dir on exit
y ~/Downloads   # Open yazi in specific directory

# Markdown rendering
md README.md    # Render markdown in terminal

# Search and replace (serpl)
sr              # Open TUI search & replace

# Fuzzy finder with previews (television)
tv              # Open television fuzzy finder
```

### Yazi File Manager

[Yazi](https://yazi-rs.github.io/) is a blazing fast terminal file manager
written in Rust with async I/O. It supports image preview in Ghostty and Kitty.

```bash
# Open yazi (use 'y' wrapper to cd on exit)
y

# Navigation
# h/l or ←/→  - Parent/Child directory
# j/k or ↑/↓  - Move cursor
# Enter       - Open file
# q           - Quit (no cd)
# Shift+Q     - Quit (cd to current dir, via 'y' wrapper)
```

Configuration: `~/.config/yazi/yazi.toml`

### Mise Version Manager

[Mise](https://mise.jdx.dev/) manages dev tool versions per-project. It
replaces nvm, pyenv, rbenv, and similar tools with one consistent interface.

```bash
# Check installed tools
mise ls

# Install a specific version
mise use node@22
mise use python@3.13

# Per-project config (create .mise.toml in project root)
mise use node@18    # creates/updates .mise.toml

# Global config
mise use -g node@lts python@3.13

# Reads existing version files (.nvmrc, .python-version, etc.)
```

Configuration: `~/.config/mise/config.toml`

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
│   ├── kitty/         # Kitty terminal configuration
│   ├── bat/           # Bat themes
│   └── ripgrep/       # Ripgrep configuration
├── .ssh/
│   ├── config              # Include directive for modular SSH config
│   └── config.d/
│       └── 00-defaults.conf  # Shared SSH defaults
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

Last updated: February 2026
