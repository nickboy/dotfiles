# Neovim Configuration

Personal [LazyVim](https://lazyvim.github.io/) setup managed with
[yadm](https://yadm.io/).

## Extras

Enabled via `lazyvim.json`:

- `ai.claudecode` -- Claude Code IDE integration
  ([coder/claudecode.nvim](https://github.com/coder/claudecode.nvim))
- `ai.copilot` -- GitHub Copilot completions
- `lang.java` -- Java LSP, DAP, and formatting
- `lang.json` -- JSON schemas and validation
- `lang.markdown` -- Markdown preview and linting
- `lang.python` -- Pyright + Ruff
- `lang.rust` -- rust-analyzer, crates.nvim

## Custom Plugins

- **Catppuccin Mocha** with transparent backgrounds for Ghostty
  compatibility (`lua/plugins/catppuccin.lua`)

## Notable Options

| Option       | Value   | Notes                                             |
| ------------ | ------- | ------------------------------------------------- |
| `laststatus` | `3`     | Global statusline                                 |
| `scrolloff`  | `10`    | Lines of context around cursor                    |
| `cmdheight`  | `0`     | Hidden command line (noice.nvim handles messages) |
| `inccommand` | `split` | Live substitution preview                         |

## Key Bindings (Claude Code)

| Key          | Action                            |
| ------------ | --------------------------------- |
| `<leader>ac` | Toggle Claude Code terminal       |
| `<leader>af` | Focus Claude terminal             |
| `<leader>as` | Send selection to Claude (visual) |
| `<leader>ab` | Add current buffer to context     |
| `<leader>aa` | Accept diff                       |
| `<leader>ad` | Reject diff                       |

## Requirements

- Neovim (installed via [bob](https://github.com/MordechaiHadad/bob))
- `tree-sitter-cli` via cargo (not Homebrew)
- Claude Code CLI for the claudecode extra
