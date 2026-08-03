# Work-Machine Deployment Checklist

Deploying these dotfiles onto a machine that already has its own
configuration (work laptop, corporate Mac). The repo is PUBLIC — the
prime directive: **anything work-specific (internal endpoints, proxy,
model names, internal tooling) goes in machine-local files only and
is never committed.**

## Before cloning

- [ ] Back up existing Claude Code config — `yadm clone` will take
  over `~/.claude/settings.json` and conflicts get messy after:

  ```bash
  cp -r ~/.claude ~/claude-backup-before-yadm
  ```

- [ ] Note any other dotfiles the machine already customizes
  (`~/.zshrc`, `~/.gitconfig`, `~/.ssh/config`) — same reasoning.

## Clone

```bash
# HTTPS works anonymously (no SSH agent on a fresh machine yet):
yadm clone https://github.com/nickboy/dotfiles.git
yadm status   # review conflicts/local modifications before anything else
```

Switch the remote to SSH only after an SSH key exists on the machine
(see the README install section). On a work machine that may mean a
work key, not 1Password.

## Reconcile Claude Code settings

Precedence (highest wins): managed-settings.json (MDM/org — never
fight it) → `settings.local.json` (machine-local, gitignored) →
`settings.json` (tracked, shared).

- [ ] Merge work-required entries from the backup into
  `~/.claude/settings.local.json`: auth/gateway (Bedrock, proxy,
  `apiKeyHelper`), org permission policies, work-only plugins.
- [ ] Model override: tracked settings pin a personal model; if the
  work plan lacks access, set `model` in `settings.local.json`.
- [ ] The tracked SessionStart hook
  `~/.claude/hooks/herdr-agent-state.sh` is a herdr-generated
  artifact. Either run `herdr integration install claude`
  (see [herdr-setup.md](herdr-setup.md)) or expect a harmless hook
  error each session until you do.

## Git identity

- [ ] `~/.gitconfig` is untracked by design — set the work name,
  email, and signing there. Tracked config only carries neutral
  defaults (osxkeychain, delta, zdiff3).
- [ ] Do NOT copy the personal machine's signing setup; sign with a
  work key or not at all. Tracked `~/.ssh/allowed_signers` holds
  public keys only — harmless.

## Homebrew

- [ ] Review the Brewfile before `brew bundle` — it targets a
  personal machine (spotify, iina, adguard, setapp, 1password casks).
  Install selectively where MDM or policy applies.

## Known gotchas (learned on the primary machine)

- [ ] macOS notification permission is per-app: the first OSC 777
  banner from Ghostty triggers a permission prompt — **allow it**,
  or you get sound-but-no-banner. Verify registration with
  `defaults read com.apple.ncprefs apps`.
- [ ] `~/CLAUDE.md` applies to every Claude session under `~`. Its
  git rules describe the personal setup (1Password SSH); if the work
  machine uses enterprise hosting, flag it and make those sections
  conditional rather than fighting them ad hoc.
- [ ] herdr (if used): follow [herdr-setup.md](herdr-setup.md) —
  version lockstep with any remote, server started from a clean
  login shell, clients re-attach after toast-config changes.

## Verify

```bash
bash ~/test-dotfiles.sh        # full local suite
claude                          # starts without hook errors
type cd                         # alias for z (zoxide active)
```
