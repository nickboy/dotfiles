---
name: dotfiles-editors
description: |
  Use when user mentions "neovim", "nvim", "LazyVim", "lazy.nvim", "zed",
  "editor config", "treesitter", "TSUpdate", "bob", or discusses editor
  configuration and plugin management.
version: 1.0.0
tools: Read, Glob, Grep, Bash, Edit
user-invocable: true
---

# Editor Configuration

## Neovim (LazyVim)

### Structure

- Config root: `~/.config/nvim/`
- Entry point: `~/.config/nvim/init.lua`
- Plugin lock: `~/.config/nvim/lazy-lock.json`
- Core configs: `~/.config/nvim/lua/config/`
  - `autocmds.lua` — Auto commands
  - `keymaps.lua` — Key bindings
  - `lazy.lua` — Lazy.nvim bootstrap
  - `options.lua` — Editor options
- Custom plugins: `~/.config/nvim/lua/plugins/`

### Version Management

Neovim is managed by **bob** (not Homebrew):

```bash
bob use stable        # Switch to stable
bob use nightly       # Switch to nightly
bob update            # Update current version
bob ls                # List installed versions
```

Binary location: `~/.local/share/bob/nvim-bin`

### Treesitter Critical Notes

- nvim-treesitter uses **`main` branch** (not `master`) since May 2025
- `tree-sitter-cli` must be installed via cargo, NOT Homebrew:

  ```bash
  cargo install --locked tree-sitter-cli
  ```

- Homebrew's `tree-sitter` package is just a library, not the CLI
- noice.nvim requires these parsers: `vim`, `regex`, `lua`, `bash`,
  `markdown`, `markdown_inline`
- Always run `:TSUpdate` after updating nvim-treesitter to sync parsers

### Plugin Updates

```bash
# Headless sync (for automation)
nvim --headless '+Lazy! sync' +qa

# Headless treesitter update
nvim --headless '+TSUpdate' +qa
```

### Making Changes

1. Edit files in `~/.config/nvim/lua/plugins/` for plugins
2. Edit files in `~/.config/nvim/lua/config/` for core settings
3. Restart Neovim to apply changes

## Zed Editor

### Configuration

- Config file: `~/.config/zed/settings.json`
- Changes apply automatically (no restart needed)

### Current Settings

- Vim mode enabled with relative line numbers
- Theme: One Dark
- Font: JetBrains Mono
- AI: Claude 3.5 Sonnet integration
- Format on save enabled
- Language-specific formatters configured
- Git inline blame enabled
- Edit predictions disabled for sensitive files
- Telemetry disabled
