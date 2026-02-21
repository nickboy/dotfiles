# Neovim Configuration

Personal [LazyVim](https://lazyvim.github.io/) setup managed with
[yadm](https://yadm.io/).

## Extras

Enabled via `lazyvim.json`:

- `ai.claudecode` -- Claude Code IDE integration
  ([coder/claudecode.nvim](https://github.com/coder/claudecode.nvim))
- `ai.copilot` -- GitHub Copilot completions
- `dap.core` -- Debug Adapter Protocol (step-through debugging)
- `editor.dial` -- Toggle booleans, increment dates with `<C-a>/<C-x>`
- `editor.harpoon2` -- Mark files and jump with `<leader>1-9`
- `editor.illuminate` -- Highlight all instances of symbol under cursor
- `editor.inc-rename` -- Live preview when renaming via LSP (`<leader>cr`)
- `editor.refactoring` -- Extract variable/function, inline, rename
- `lang.docker` -- Dockerfile and compose LSP
- `lang.go` -- gopls, gofmt, delve debugger
- `lang.java` -- Java LSP, DAP, and formatting
- `lang.json` -- JSON schemas and validation
- `lang.markdown` -- Markdown preview and linting
- `lang.python` -- Pyright + Ruff
- `lang.rust` -- rust-analyzer, crates.nvim
- `lang.toml` -- TOML syntax and LSP (Cargo.toml, pyproject.toml)
- `lang.typescript` -- ts\_ls, prettier, eslint
- `test.core` -- Run tests from editor (`<leader>t` bindings)
- `ui.treesitter-context` -- Sticky header showing current function/class

## Custom Plugins

- **Catppuccin Mocha** with transparent backgrounds for Ghostty
  compatibility (`lua/plugins/catppuccin.lua`)
- **Custom Dashboard** with ASCII art header (`lua/plugins/dashboard.lua`)
- **Smooth Scroll** tuning — 150ms linear animation
  (`lua/plugins/snacks-extras.lua`)

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
