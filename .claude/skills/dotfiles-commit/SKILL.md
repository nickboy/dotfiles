---
name: dotfiles-commit
description: |
  Use when user asks to "commit", "push", "create PR", "pull request",
  mentions "yadm add", "yadm commit", "yadm push", or discusses version
  control operations for this dotfiles repository.
version: 1.0.0
tools: Read, Glob, Grep, Bash, Edit
user-invocable: true
---

# Dotfiles Commit Workflow

## Pre-commit Checklist

Before every commit, run these in order:

1. Run the test suite:

   ```bash
   bash ~/test-dotfiles.sh
   ```

2. Run markdown lint on all docs:

   ```bash
   yadm ls-files '*.md' | xargs npx markdownlint-cli
   ```

3. Fix ALL lint errors before proceeding — no exceptions.

## Common Markdownlint Errors

- **MD022**: Headings need blank lines above and below
- **MD031**: Code blocks need blank lines above and below
- **MD032**: Lists need blank lines above and below
- **MD013**: Keep lines under 80 characters when possible

## Yadm Commands (NOT git)

All operations use `yadm`, never `git`:

```bash
yadm status           # Check status
yadm diff             # View changes
yadm add <file>       # Stage file
yadm commit -m "msg"  # Commit
yadm push             # Push to GitHub
```

## Signing & Push Transport

Scope: personal machines. Work machines follow their own untracked
`~/.gitconfig` (see `docs/work-machine-checklist.md`).

- Commits are SSH-signed via the 1Password agent (`op-ssh-sign`,
  machine-local `~/.gitconfig`). If a commit fails with a signing
  error, 1Password is probably locked — unlock it and retry; never
  work around it with `--no-gpg-sign`.
- The yadm remote is `git@github.com:` (SSH through the 1Password
  agent). HTTPS pushes fail on this machine — never "fix" a push
  failure by switching the remote back to HTTPS.

## Author Configuration

Verify before first commit in a session:

```bash
yadm gitconfig --get user.name   # Should be: Tzu-Hua(Nick) Liu
yadm gitconfig --get user.email  # Should be: nickboy@users.noreply.github.com
```

Set if missing:

```bash
yadm gitconfig user.name "Tzu-Hua(Nick) Liu"
yadm gitconfig user.email "nickboy@users.noreply.github.com"
```

`yadm gitconfig`, **not** `yadm config` — the latter writes yadm's own
settings namespace and has no effect on commit authorship. This matters
most on a work machine, where a corp-managed `~/.gitconfig` supplies a
company address that would otherwise be published to this public repo.

## Conventional Commit Format

Use these prefixes:

- `feat:` — New features
- `fix:` — Bug fixes
- `docs:` — Documentation changes
- `test:` — Test additions or changes
- `refactor:` — Code refactoring
- `style:` — Formatting changes
- `chore:` — Maintenance tasks

Example: `yadm commit -m "feat: add tmux session management script"`

## Commit Rules

- Do NOT include Claude co-author or AI-generated tags
- Do NOT use `git` — always use `yadm`
- Every commit MUST pass markdown linting
- Run `bash ~/test-dotfiles.sh` before committing

## Pull Request Workflow

```bash
# Create feature branch
yadm checkout -b feature/branch-name

# Make changes, test, commit
bash ~/test-dotfiles.sh
yadm ls-files '*.md' | xargs npx markdownlint-cli
yadm add <files>
yadm commit -m "feat: description"

# Push branch
yadm push -u origin feature/branch-name

# Create PR
yadm pr create --title "PR title" --body "PR description"
```

If the `pr` alias is not configured:

```bash
yadm gitconfig alias.pr '!f() { GIT_DIR=$HOME/.local/share/yadm/repo.git \
  GIT_WORK_TREE=$HOME gh pr "$@"; }; f'
```

Other PR operations:

```bash
yadm pr list              # List PRs
yadm pr view              # View current PR
yadm pr merge             # Merge PR
```
