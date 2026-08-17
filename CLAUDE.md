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

Highest first, as the live shell actually resolves it (`print -l
${(s/:/)PATH}`) — this list used to be written the other way round,
which mattered: it implied Homebrew always wins, so a stale binary in
`~/.local/bin` looked inert when it was in fact the one executing.

1. mise runtime shims (`~/.local/share/mise/installs/*/bin`) — node,
   python, go, ruby, ahead of everything
2. `~/Library/Application Support/bob/nvim-bin` (Neovim; bob's git-dev
   build moved here July 2026 — `~/.local/share/bob/nvim-bin` is the
   legacy fallback)
3. `~/.cargo/bin` (Rust)
4. `~/.local/bin` (user scripts)
5. `/opt/homebrew/bin` (Homebrew) — **last of the four**, so anything
   in `~/.local/bin` shadows a brew-installed command of the same name

Check with `which -a <cmd>` before assuming which copy runs.

## Mandatory Rules

1. **Use yadm, not git** — All dotfile operations use `yadm` commands.
   Never use `git` directly.

2. **Respect existing patterns** — Check neighboring files for conventions,
   use existing libraries/frameworks, follow established code style.

3. **Path conventions** — Homebrew is at `/opt/homebrew` (Apple Silicon).
   Use `$HOME` instead of hardcoded user paths. Scripts must be `chmod +x`.

4. **Lint-free commits** — Every commit MUST pass markdown linting.
   Run `yadm ls-files '*.md' | xargs npx markdownlint-cli` before
   any commit. Fix ALL lint errors, no exceptions. Never use
   `'**/*.md'` from `~` — it scans the entire home directory and hangs.

5. **Run tests before committing** — `bash ~/test-dotfiles.sh`.
   Enforcement is two layers: the yadm hook at
   `~/.config/yadm/hooks/pre_commit` runs the suite on `yadm commit`
   (bypassable via `--no-verify` or raw `GIT_DIR=… git commit`), and
   CI blocks on the same checks — treat CI as the authoritative gate.

6. **No AI tags in commits** — Do NOT include Claude co-author or
   AI-generated tags in commit messages.

7. **Zsh plugin loading** — Zinit manages most plugins, Oh-My-Zsh
   provides the framework. Never duplicate plugin loading between them.

8. **Neovim/Treesitter** — nvim-treesitter uses `main` branch (not
   `master`). `tree-sitter-cli` must be installed via cargo, not
   Homebrew. Run `:TSUpdate` after updating nvim-treesitter.

9. **No secrets in dotfiles** — **this repo is public; treat every
   tracked file as published.** Nothing here is semi-private, and CI
   does not verify signatures, so do not assume it will catch an
   unsigned or unwanted commit. Use `.gitignore` for sensitive files.
   The invariant on EVERY machine: credentials and identity live in
   untracked files (`~/.gitconfig`, machine ssh config), never in
   tracked ones. The specifics below describe the PERSONAL machines;
   on work machines (enterprise hosting, no 1Password) follow that
   machine's own `~/.gitconfig` instead — see
   `docs/work-machine-checklist.md`.

   Personal machines: GitHub auth goes over **SSH through the
   1Password agent** — the key lives in 1Password with no private key
   on disk, routed by `~/.ssh/config.d/10-github-1password.conf`, so
   remotes must use `git@github.com:` and not `https://`. The same
   key signs commits (`op-ssh-sign`, configured in the untracked
   `~/.gitconfig`; public keys in tracked `~/.ssh/allowed_signers`).

   Two gotchas. A 1Password key must be added to GitHub as an
   **authentication** key, not only a signing key; GitHub keeps those
   lists separate, and a signing-only key still fails `git push`.
   And `00-defaults.conf` sets `IdentitiesOnly yes` globally, which
   makes ssh ignore agent keys, so any host using 1Password needs
   `IdentitiesOnly no`.

   Git Credential Manager was removed 2026-08. HTTPS remotes fail with
   "Invalid username or token" (the `osxkeychain`-cached credential is
   stale) — switch the remote to SSH rather than trying to repair the
   credential.

10. **A failed query is not a negative result** — confirm a query
    reached the right place before reading "nothing found" as "nothing
    exists". Four variants have already produced wrong conclusions
    here — the fourth while reviewing this very rule, where the wrong
    conclusion was reached and caught before it was acted on:

    - **yadm state**: use `yadm remote -v` / `yadm status`, never bare
      `git` from `$HOME`. The bare repo lives in
      `~/.local/share/yadm/repo.git`, so `git remote -v` answers
      `fatal: not a git repository` — a query that never ran, once
      reported as "no remotes configured". Rule 1 forbids bare `git`
      for write correctness; this is the same rule for reads.
    - **Branch protection**: query `/repos/{owner}/{repo}/rulesets`.
      The older `/branches/*/protection` endpoint returns 404 for a
      branch protected by a ruleset — wrong API, not an unprotected
      branch.
    - **App usage**: `mdls kMDItemLastUsedDate` is null both for an
      app never opened AND after a Spotlight metadata reset. Judge
      "still needed?" from user data — documents, lock files,
      container contents — not from an index field. This one nearly
      uninstalled an Office install holding 150 documents.
    - **Isolated-environment probes**: a redirected environment may not
      redirect every path the program reads. `HOME=/tmp/fake ghostty
      +show-config` honours `$XDG_CONFIG_HOME` but resolves
      `~/Library/Application Support` from the REAL home, so a planted
      config there is invisible and the probe reads "not loaded" for
      any input. Test with a marker key in the real path (append,
      observe, restore, verify the checksum) rather than a fake HOME.

    The repo's own state is deliberately NOT recorded here. A dated
    snapshot of mutable remote state is the cached answer this rule
    exists to warn about — it looks like it means you need not run the
    query. Check it: `gh api repos/nickboy/dotfiles/rulesets` (the
    ruleset endpoint, not `/branches/*/protection`), and `yadm remote -v`.

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
- **hackernews-summary** — Fetch and summarize top 30 HN stories
  (full front page) in Traditional Chinese

---

*Verify current state with `yadm status`. Check actual file contents
before making modifications.*
