# Work-Machine Deployment Checklist

Deploying these dotfiles onto a machine that already has its own
configuration (work laptop, corporate Mac). The repo is PUBLIC — the
prime directive: **anything work-specific (internal endpoints, proxy,
model names, internal tooling) goes in machine-local files only and
is never committed.**

Two paths: **update** (yadm already set up with an older version of
this repo — most common) or **fresh clone**. Update path first.

## Update path (yadm already installed)

- [ ] Assess before pulling:

  ```bash
  yadm log --oneline -1     # how far behind
  yadm status               # LOCAL modifications to tracked files?
  yadm diff                 # review them — this is the conflict risk
  ```

- [ ] Local modifications to tracked files (settings.json is the
  usual suspect) block or conflict the pull. Move work-specific
  values into `~/.claude/settings.local.json`, then either commit
  keepers on a branch or discard: `yadm checkout -- <file>`.
- [ ] Pull (HTTPS pull works anonymously on this public repo):

  ```bash
  yadm pull
  yadm alt          # regenerate templates (plist, herdr config)
  ```

- [ ] Post-pull migration (delta since mid-2026 versions):
  - `yadm bootstrap` — idempotent; installs TPM/pay-respects/etc.
  - `brew bundle --file=~/Brewfile` selectively (`gitleaks` matters:
    the pre-commit hook uses it; it skips with a warning if absent)
  - tmux: `prefix+I` to sync plugins;
    tmux-claude-session-manager >= 1.1.0 reads status from
    `claude agents` — the old state.sh hooks are gone from
    settings.json, never re-add them
  - Reconcile `~/.claude/settings.json` with the backup (work model /
    auth → settings.local.json; herdr SessionStart hook warns
    harmlessly until `herdr integration install claude` or herdr is
    skipped entirely)
  - `yadm bootstrap` — idempotent; now covers the machine services
    (`brew services start atuin`, `ya pkg install`, bat cache,
    treesitter) and ends by running the full test suite as
    verification. Prefer it over running those steps by hand; a
    standalone `bash ~/test-dotfiles.sh` afterwards re-checks anytime.
  - Verify desktop notifications actually render on this machine (MDM
    can block them, and maintenance-failure banners matter most here):
    `terminal-notifier -title test -message ok` — a banner must appear.
- [ ] Push transport for THIS machine: keep HTTPS +
  `gh auth login`, or a work SSH key — set in the machine's untracked
  `~/.gitconfig`. Do not copy the personal 1Password setup.
- [ ] Machine-only maintenance steps go in `~/.daily-maintenance.local`
  (untracked). `daily-maintenance.sh` sources it as its LAST step, so
  a failure there costs nothing but a line in the summary, and skips
  it entirely under `--auto` because the launchd run has nobody
  present to answer a 2FA prompt. Put anything touching remote hosts
  or corp tooling there rather than in the tracked script.

## Fresh-clone path

### Before cloning

- [ ] Back up existing Claude Code config — `yadm clone` will take
  over `~/.claude/settings.json` and conflicts get messy after:

  ```bash
  cp -r ~/.claude ~/claude-backup-before-yadm
  ```

- [ ] Note any other dotfiles the machine already customizes
  (`~/.zshrc`, `~/.gitconfig`, `~/.ssh/config`) — same reasoning.

### Clone

```bash
# HTTPS works anonymously (no SSH agent on a fresh machine yet):
yadm clone https://github.com/nickboy/dotfiles.git
yadm status   # review conflicts/local modifications before anything else
```

Switch the remote to SSH only after an SSH key exists on the machine
(see the README install section). On a work machine that may mean a
work key, not 1Password.

### Reconcile Claude Code settings

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
- [ ] **Set the repo identity explicitly, or a commit publishes your
  work email.** A corp-managed `~/.gitconfig` sets a company address,
  and yadm inherits it — so a commit to this PUBLIC repo carries that
  address forever. Pin the repo-local identity instead:

  ```bash
  yadm gitconfig user.name  "Your Name"
  yadm gitconfig user.email "you@users.noreply.github.com"
  yadm gitconfig --get user.email        # verify before the first commit
  ```

  Note `yadm gitconfig`, **not** `yadm config`: the latter writes
  yadm's own settings namespace and silently has no effect on commit
  authorship. `yadm config user.email` returning empty while commits
  still carry an address is the tell.

- [ ] **Verify push actually works before you need it.** A crashing
  credential helper fails in a confusing way:

  ```text
  error: ...git-credential-manager get died of signal 11
  fatal: could not read Username for 'https://github.com'
  ```

  Fix with the GitHub CLI rather than debugging the helper, and check
  with a dry run:

  ```bash
  gh auth status && gh auth setup-git
  yadm push --dry-run
  ```

- [ ] For corp repos, set the work identity in jj too:
  `jj config set --repo user.email <work-email>` (the tracked jj
  config carries the personal default).

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
- [ ] **A corp-managed toolchain can shadow a Homebrew formula, and the
  error suggests the one fix you must not apply.** `brew bundle` reports
  something like

  ```text
  Target /opt/homebrew/bin/g[ already exists.
  To force the link and overwrite all conflicting files:
    brew link --overwrite coreutils
  ```

  Those entries may not be stale Homebrew symlinks. On a managed machine
  they can be tiny root-owned shell scripts, placed by the config
  management system, that exec a vendor build of the same tool from a
  different prefix. `--overwrite` deletes files that system owns, it
  restores them on its next run so the conflict returns, and anything
  depending on the vendor build can break in between.

  The tell, before you decide anything is broken: a real Homebrew link is
  a **symlink owned by you**; a managed shim is a **regular file owned by
  root**.

  ```bash
  ls -la /opt/homebrew/bin/<name>     # symlink + your user, or file + root?
  ```

  When it is a shim, leave the formula unlinked and treat the recurring
  "needs to be linked" report as a false alarm on that machine. Check the
  capability you actually depend on instead of the link status. For
  coreutils here that is timeout's `--foreground`, which daily-maintenance
  needs and the shimmed build (GNU coreutils 8.32) provides:

  ```bash
  command -v gtimeout && gtimeout --foreground 1 true && echo ok
  ```

- [ ] **`~/.ssh/config.d/*` is first-match-wins, and `00-defaults.conf`
  has a `Host *` block.** ssh takes the FIRST value it sees for each
  keyword and reads the directory in glob order, so a per-host block
  in a later file is silently ignored for anything `Host *` already
  set — `ControlPersist`, `ControlPath`, `ServerAlive*`. A host block
  that needs to override those must sort BEFORE `00-`, e.g.
  `0-myhost.conf`. Always confirm with the resolver, never by reading
  the files:

  ```bash
  ssh -G myhost | grep -E 'controlpersist|serveralive'
  ```

- [ ] **A "clean" tree that still refuses to merge is a racy index.**
  If `yadm pull` aborts with *"Your local changes … would be
  overwritten"* while `yadm status` shows nothing, some tool rewrote
  a tracked file with identical content but a fresh mtime.
  `status` compares content; merge trusts the timestamp. Backdate the
  file and refresh rather than hunting for a change that is not there:

  ```bash
  touch -t 202401010000 ~/.claude/settings.json
  yadm gitconfig --local --unset-all core.trustctime 2>/dev/null || true
  git --git-dir="$(yadm introspect repo)" --work-tree="$HOME" \
      update-index -q --refresh
  yadm pull --ff-only
  ```

  `.claude/settings.json` is the usual culprit: Claude Code rewrites
  it on its own (plugin and permission state), so on a machine with
  work-only plugins expect it to be permanently modified. Discard it
  before each pull rather than trying to keep it clean.

- [ ] **Claude Code effort: `settings.json` cannot express `max`.**
  The schema is
  `enum(["low","medium","high","xhigh"]).optional().catch(void 0)`,
  and that `.catch()` means an out-of-range value is swallowed in
  silence — no error, the level just falls back to the default. So
  `"effortLevel": "max"` looks applied and is not. `max` exists only
  as `--effort max` at launch or `/effort max` in-session, and
  `CLAUDE_EFFORT` is write-only (exported for hooks, never read back).
  A machine that wants `max` by default needs a `PATH` shim in front
  of `claude`; see [herdr-setup.md](herdr-setup.md).

- [ ] **Anything a herdr-resumed pane must inherit belongs in
  `~/.zshenv`.** A restore runs a bare `claude --resume <id>` from a
  NON-interactive shell, which reads `.zshenv` and nothing else —
  `.zshrc` never runs there, so env set in the `.zshrc` chain
  disappears across a server restart.

## Verify

```bash
bash ~/test-dotfiles.sh        # full local suite
claude                          # starts without hook errors
type cd                         # alias for z (zoxide active)
```
