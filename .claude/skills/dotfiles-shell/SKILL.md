---
name: dotfiles-shell
description: |
  Use when user mentions "zshrc", "shell config", "zinit", "oh-my-zsh",
  "tmux", "alias", "fzf", "zoxide", "sesh", "ghostty", "kitty",
  "terminal", "atuin", "starship", "carapace", "yazi", "mise",
  "television", "glow", "serpl", "jj", "jujutsu", or discusses
  shell, terminal, or multiplexer configuration.
version: 1.0.0
tools: Read, Glob, Grep, Bash, Edit
user-invocable: true
---

# Shell & Terminal Configuration

## Zsh (.zshrc)

### Architecture (loading order)

1. Early environment setup (PATH, compilation flags)
2. Oh-My-Zsh framework loading (minimal plugins)
3. Zinit plugin manager with lazy loading
4. Tool integrations (fzf, zoxide, starship, atuin, carapace, mise)
5. Modern CLI aliases

### Critical Rules

- **Zinit** manages most plugins — do not duplicate loading
- **Oh-My-Zsh** provides the framework — loaded before Zinit
- Oh-My-Zsh libraries loaded via Zinit: `directories`, `history`, `misc`
- Oh-My-Zsh plugins loaded via Zinit: `common-aliases`, `colored-man-pages`,
  `web-search`, `sudo`, `extract`, `copypath`, `copyfile`, `jsontools`,
  `encode64`

### PATH Priority

1. `/opt/homebrew/bin` — Apple Silicon Homebrew
2. `~/.local/bin` — User scripts
3. `~/.cargo/bin` — Rust toolchain
4. `~/.local/share/bob/nvim-bin` — Neovim versions

### Key Integrations

- **FZF**: Fuzzy finder with Catppuccin theme and preview windows
- **Television**: Modern fuzzy finder with built-in previews and channels
- **Zoxide**: Smart `cd` replacement (`z project` jumps to frecent match)
- **Starship**: Cross-shell prompt
- **Atuin**: Enhanced shell history with SQLite, fuzzy search, syntax
  highlighting. Ctrl+R for interactive search.
- **Carapace**: Universal command completions
- **Mise**: Polyglot dev tool version manager (node, python, go, ruby).
  Config: `~/.config/mise/config.toml`. Per-project: `.mise.toml`

### Notable Aliases

- `mr` — Maintenance run
- `ms` — Maintenance status
- `ml` — Maintenance logs
- `cat` → `bat`, `vim` → `nvim`, `cd` → `z`
- `y` → yazi (file manager, cd on exit), `sr` → serpl, `md` → glow
- Modern CLI replacements: `ls`→eza, `du`→dust, `df`→duf, `top`→btop,
  `grep`→rg, `find`→fd, `dig`→doggo, `ps`→procs

## Yazi File Manager

- Config: `~/.config/yazi/yazi.toml`
- Use `y` wrapper function (cd to last dir on exit) instead of `yazi`
- Supports image preview in Ghostty/Kitty via native protocols
- Navigation: h/l parent/child, j/k up/down, Enter open, q quit

## Tmux (.tmux.conf)

### Basics

- **Prefix**: `Ctrl-A` (remapped from Ctrl-B)
- Vi mode, mouse support enabled
- Windows/panes numbered starting at 1

### Key Bindings

- `Ctrl-A + \` — Horizontal split
- `Ctrl-A + -` — Vertical split
- `Ctrl-A + h/j/k/l` — Navigate panes (vim-style)
- `Ctrl-h/j/k/l` — Seamless navigation between tmux panes and vim splits
- `Ctrl-A + T` — Open sesh session switcher
- `Ctrl-A + r` — Reload config
- `Ctrl-A + I` — Install TPM plugins

### Plugins (via TPM)

- **vim-tmux-navigator** — Seamless vim/tmux pane switching
- **tmux-resurrect** — Session persistence across restarts
- **tmux-continuum** — Auto-save sessions
- **Catppuccin theme** — Mocha variant
- **tmux-claude-session-manager** — `prefix+y` launch/attach Claude for the
  cwd; `prefix+u` fzf picker of live Claude sessions (working/waiting/idle
  status via `scripts/state.sh` hooks + live preview)

### Session Management (sesh)

```bash
s               # Interactive session picker with fzf preview
s myproject     # Connect or create from zoxide path
sn              # Create session named after current directory
sl              # List all sessions
```

Inside tmux, `Ctrl-A + T` opens the advanced session switcher with:
Tab/Shift-Tab to navigate, Ctrl-x for zoxide dirs, Ctrl-d to kill session.

## Claude Code Sessions

- **Auto-naming** via a `SessionStart` hook
  (`~/.local/bin/claude-name-session`, wired in `settings.json`): sets each
  new session's `sessionTitle` to `project/branch` (`host:project/branch`
  over SSH) — works for every launch method (shell, nvim, ClaudeDeck, SSH).
  Names on `startup`, and on `resume` only when still unnamed (the resume
  payload carries `session_title`, so a manual `/rename` is never clobbered;
  this also back-names old unnamed sessions when you resume them). Portable:
  jq with a python3 fallback for minimal remotes.
- **`claude()` wrapper** (`.zshrc`): decorates tmux only — renames the
  window to `🤖 <project/branch>` and restores auto-rename on exit.
  Subcommands and print mode pass through untouched.
- **Find/resume sessions:** `/resume` → `Ctrl+A` (all projects), `Ctrl+W`
  (worktrees), `Ctrl+B` (branch), `/` search, or paste a PR URL.
  `claude --resume <name>`, `claude --continue`, `claude agents --all`.
- **Remote (SSH + tmux):** prefer **detach (`Ctrl-a d`), not exit** — the
  agent keeps running; reconnect with `ssht host`. Run `/resume` on the
  remote to browse that host's sessions. F12 toggles nested tmux.

## Git Configuration (.gitconfig)

- Pager: **delta** with syntax highlighting
- Merge conflict style: **zdiff3**
- Credential helper: Git Credential Manager
- User: Nick Liu (`nickboy@users.noreply.github.com`)

## Terminal Emulators

### Ghostty (`~/.config/ghostty/config`)

- Transparent background (0.75 opacity) with blur
- Shell integration with working directory tracking (OSC 7)
- Clipboard protection with bracketed paste
- Custom keybinds: `Cmd+D` split down, `Cmd+Shift+D` split right
- Cursor shaders in `~/.config/ghostty/shaders/`
- `Cmd+Shift+,` to reload config
- Theme: Catppuccin Mocha, Font: Hack Nerd Font

### Kitty (`~/.config/kitty/kitty.conf`)

- Monaspace fonts with ligatures and texture healing
- Cursor trail animation (Kitty 0.37+)
- Transparent background (0.75 opacity) with blur
- Remote control via unix socket
- 7 built-in layouts (tall, stack, fat, grid, splits, etc.)
- Key bindings: `Cmd+D` horizontal split, `Cmd+Shift+D` vertical split,
  `Ctrl+h/j/k/l` vim-style navigation
- Kittens: icat (images), hints (URLs), diff, themes, unicode_input
- Theme: Catppuccin Mocha
