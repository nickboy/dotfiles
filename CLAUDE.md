# Nick's Dotfiles — AI Assistant Instructions

Personal dotfiles managed with [yadm](https://yadm.io/) at
<https://github.com/nickboy/dotfiles.git>.

## Architecture

macOS (Apple Silicon) development environment:

- **Shell**: Zsh + Oh-My-Zsh framework + Zinit plugin manager
- **Terminals**: Ghostty, Kitty (both Catppuccin Mocha themed)
- **Multiplexer**: tmux with sesh session manager
- **Editors**: Neovim (LazyVim via bob) and Zed
- **Packages**: Homebrew at `/opt/homebrew`
- **Prompt**: Starship
- **History**: Atuin
- **Completions**: Carapace
- **Git**: delta pager, zdiff3 merge style
- **Version Control**: yadm (NOT git) for all dotfile operations

### PATH Priority

1. `/opt/homebrew/bin` (Homebrew)
2. `~/.local/bin` (user scripts)
3. `~/.cargo/bin` (Rust)
4. `~/.local/share/bob/nvim-bin` (Neovim)

## Mandatory Rules

1. **Use yadm, not git** — All dotfile operations use `yadm` commands.
   Never use `git` directly.

2. **Respect existing patterns** — Check neighboring files for conventions,
   use existing libraries/frameworks, follow established code style.

3. **Path conventions** — Homebrew is at `/opt/homebrew` (Apple Silicon).
   Use `$HOME` instead of hardcoded user paths. Scripts must be `chmod +x`.

4. **Lint-free commits** — Every commit MUST pass markdown linting.
   Run `npx markdownlint-cli '**/*.md' --ignore node_modules` before
   any commit. Fix ALL lint errors, no exceptions.

5. **Run tests before committing** — `bash ~/test-dotfiles.sh`

6. **No AI tags in commits** — Do NOT include Claude co-author or
   AI-generated tags in commit messages.

7. **Zsh plugin loading** — Zinit manages most plugins, Oh-My-Zsh
   provides the framework. Never duplicate plugin loading between them.

8. **Neovim/Treesitter** — nvim-treesitter uses `main` branch (not
   `master`). `tree-sitter-cli` must be installed via cargo, not
   Homebrew. Run `:TSUpdate` after updating nvim-treesitter.

9. **No secrets in dotfiles** — Use `.gitignore` for sensitive files.
   Git credentials managed by Git Credential Manager.

## Skills

Detailed workflows are in `~/.claude/skills/`. Claude loads these
automatically based on context:

- **dotfiles-commit** — Yadm commit/push/PR workflow, conventional
  commits, pre-commit checklist, author config
- **dotfiles-test** — Test suite, linters (shellcheck, markdownlint,
  yamllint), CI/CD pipeline, pre-commit hook
- **dotfiles-maintenance** — Daily automation (brew, zinit, bob,
  LazyVim, treesitter), control commands, Brewfile management
- **dotfiles-editors** — Neovim/LazyVim config, treesitter details,
  bob version manager, Zed settings
- **dotfiles-shell** — Zsh/Zinit/Oh-My-Zsh architecture, tmux config,
  terminal emulators (Ghostty, Kitty), Atuin, sesh, aliases

---

*Verify current state with `yadm status`. Check actual file contents
before making modifications.*
