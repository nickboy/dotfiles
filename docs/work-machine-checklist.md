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
- [ ] **Set the machine class — do this BEFORE the first pull.**

  ```bash
  yadm config local.class work      # personal machines: `personal`
  ```

  This is the machine's IDENTITY, not a feature switch. Rule 9 keys
  credential handling off it, so never set `personal` on a corp machine
  to borrow some behaviour — opt into that behaviour by its own class
  instead, as below.

- [ ] **Opt into the herdr preview channel — only if you want it.**

  ```bash
  yadm config --add local.class herdr-preview
  yadm alt          # regenerate the herdr config from the template
  ```

  `preview` ships most days; `stable` has sat on v0.8.0 since
  2026-08-03. Without this extra class the machine renders
  `channel = "stable"`, and that is the default for a reason — a machine
  nobody opted in cannot drift onto unreleased builds. The failure
  direction is only ever "stayed on stable".

  `yadm.class == "X"` is a MEMBERSHIP test over every class, so `work`
  and `herdr-preview` coexist and the identity stays honest. Verified by
  rendering: `work` alone → stable, `work,herdr-preview` → preview.

  **Migration:** `personal` alone used to select preview and no longer
  does. Every personal machine needs the `--add` above once, or it
  silently drops to stable at the next `yadm alt`.

  Confirm what actually rendered, never assume:

  ```bash
  grep -A2 '^\[update\]' ~/.config/herdr/config.toml
  ```

- [ ] Pull (HTTPS pull works anonymously on this public repo):

  ```bash
  yadm pull
  yadm alt          # regenerate templates (plist, herdr config)
  ```

- [ ] Post-pull migration (delta since mid-2026 versions):
  - Keyboard copy (2026-08-06, PRs #76–#78; reworked 2026-08-09):
    `prefix+O` sends Claude Code's own `/copy` to the pane, which is
    what puts the reply on **your** clipboard rather than the server's.
    It only fires at a pane actually running Claude — tmux checks
    `pane_current_command`, herdr uses `agent prompt`, which refuses a
    non-agent pane rather than typing into your editor.
    **Do this once per machine:** press `prefix+O` on a reply that
    contains a code block. `/copy` will open a selector; choose
    **"3. Always copy full response"**. Without it the key sometimes
    copies and sometimes opens a picker needing a second keypress, with
    no indication why — the trigger is whether the reply happens to
    contain code. **If you skip this step the binding still works — it
    will just need a second keypress on replies containing code blocks.
    That is not a bug in the binding.** The setting writes
    `"copyFullResponse": true` into `~/.claude.json`, which is
    untracked machine-local state, so `claude-settings-sync` cannot
    install it for you; revert any time with `/config`.
    `claude-copy-last` (`ccl`) survives for the one thing `/copy`
    structurally cannot do — write to **stdout**, for piping and
    scripting (`ccl | glow`, `ccl > notes.md`); jq required (Brewfile
    has it). To activate: open a new shell (alias), `tmux source
    ~/.tmux.conf` (`prefix+P` = last shell output, `prefix+O` = last
    Claude reply, vi copy mode with `v`/`C-v`/`(`/`)`), and if herdr is
    installed, detach + re-attach the client (keys are read at attach).
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
  - herdr licensing changed 0.8.0: AGPL-3.0 → Apache-2.0, so the
    usual corp legal objection is gone — installing herdr here is now
    a policy question, not a license one. If installed: use the
    official installer, NOT brew (see docs/herdr-setup.md), and
    mirror the plugin `--ref` SHAs.
  - `yadm bootstrap` — idempotent; now covers the machine services
    (`brew services start atuin`, `ya pkg install`, bat cache,
    treesitter) and ends by running the full test suite as
    verification. Prefer it over running those steps by hand; a
    standalone `bash ~/test-dotfiles.sh` afterwards re-checks anytime.
  - Verify desktop notifications actually render on this machine (MDM
    can block them, and maintenance-failure banners matter most here):
    `terminal-notifier -title test -message ok` — a banner must appear.
  - **Ghostty was parsing its config twice** (2026-08-16, PR #93).
    Ghostty reads BOTH `~/.config/ghostty/config` and the macOS
    Application Support path; bootstrap used to symlink the second to
    the first, so every repeatable key was applied twice — 4
    `custom-shader` entries instead of 2, two extra full-screen shader
    passes per frame. Scalar keys are last-wins, so nothing looked
    wrong for as long as it lasted. `yadm bootstrap` now REMOVES that
    symlink instead of creating it, so the pull plus bootstrap fixes
    this machine too. Verify — these two numbers must match:

    ```bash
    ghostty +show-config | grep -c '^custom-shader = '
    grep -c '^custom-shader = ' ~/.config/ghostty/config
    ```

    A real file (not a symlink) at the Application Support path is left
    alone with a warning: that would be a deliberate machine-local
    override, which a work machine may legitimately have.
  - **`ll` no longer carries `--git`; `llg` does** (2026-08-16, PR #95).
    `--git` costs 2–5x and scales with the REPO, not the directory being
    listed — measured 68.8ms vs 13.9ms in a 263-file repo. If work repos
    are larger than the personal ones, the win here is bigger, not
    smaller. Needs a **new shell**, not just a pull. The flag also came
    out of `ls`/`l`/`lt`/`tree`, where the git column never rendered at
    all (output verified byte-identical) — no behaviour change there.
  - **Backup-age warning** (2026-08-16, PR #94): `daily-maintenance.sh`
    now warns when the newest completed Time Machine backup is older
    than `TM_WARN_DAYS` (default 30). It reads `SnapshotDates` from the
    TimeMachine plist, so it does not need the destination mounted.
    On a machine with **no** Time Machine destination it prints
    "No Time Machine destination configured — nothing to check" and
    stays silent, which is the correct behaviour where corp backup
    handles this. Override the threshold per machine via the exported
    `TM_WARN_DAYS` in `~/.daily-maintenance.local` if corp policy
    differs.
  - **`openlogi@latest` is a personal-machine cask.** It replaces Logi
    Options+ and only matters with Logitech peripherals attached —
    skip it here unless this machine has them, in line with the
    Brewfile review step below.
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

`~/.claude/settings.json` is **untracked** (see below), so there is no
longer a tracked file to reconcile against — only the shared keys that
`claude-settings-sync` installs.

Scopes, read out of the 2.1.220 binary rather than inferred:

| Internal name | Reported scope |
| --- | --- |
| `policySettings` | managed |
| `flagSettings` | cli flag |
| `localSettings` | project, gitignored |
| `projectSettings` | project |
| `userSettings` | user |

Note what that says about `settings.local.json`: `localSettings` is a
**project** scope ("project local settings"), and the home-directory
copy is handled by code that calls it *legacy*. This contradicts the
older note here that described it as a machine-local user tier — that
claim was never verified and is removed rather than reworded.

- [ ] **Verify the scope before relying on it.** Unresolved, and only
  testable on the work laptop: does `~/.claude/settings.local.json`
  still apply when cwd is a real project with its own `.git`/`.claude`?
  Circumstantial evidence says project-root discovery walks up to
  `~/.claude` when nothing closer exists — which would mean the
  override silently stops applying inside a work repo, exactly where it
  is needed. Test it:

  ```bash
  mkdir -p /tmp/scope-test && cd /tmp/scope-test && git init -q
  claude --print "just say ok"    # which model does the statusline report?
  ```

  If the override loses to the default inside a real repo, model/auth
  overrides belong in that repo's own `.claude/settings.local.json`,
  not the home copy — update this checklist with what you find.
- [ ] **Statusline segments** are switched per machine, not templated —
  the script is one file on both machines and only its segments differ.
  Under enterprise billing (Bedrock/Vertex) cost and burn rate are
  meaningless and `rate_limits` is absent from the payload entirely, so
  on a work machine write the untracked
  `~/.config/claude-statusline/config.sh`:

  ```bash
  SHOW_COST=0
  SHOW_BURN=0
  SHOW_RATE_LIMITS=0
  ```

  Omitting the file keeps every segment on. `SHOW_HERDR=0` also drops
  the herdr/herddeck side effects if that machine runs neither.
- [ ] Merge work-required entries from the backup into
  `~/.claude/settings.local.json`: auth/gateway (Bedrock, proxy,
  `apiKeyHelper`), org permission policies, work-only plugins.
- [ ] Model override: nothing pins a personal model any more, since
  `settings.json` is untracked — set `model` wherever the scope test
  above shows it actually applies.
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
- [ ] **Drop packages this machine should not have via
  `~/.Brewfile.skip`** (untracked, one name per line, `#` comments and
  blank lines ignored). Guarded declarations in the Brewfile disappear,
  including the tap a skipped cask came from, so `yadm bootstrap` stays
  usable instead of being something you avoid running. Two reasons a
  package belongs here rather than in an edit to the tracked Brewfile:
  the machine already receives the same tool from its own software
  management, or the package comes from a third-party tap that
  `brew upgrade --cask --greedy-latest --yes` would then auto-upgrade
  unattended. The absent file skips nothing, so a fresh machine is
  unaffected.

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

  `.claude/settings.json` used to be the usual culprit here. **On each
  machine, back it up by hand before the FIRST pull that carries the
  untracking change — that one pull still destroys it:**

  ```bash
  cp ~/.claude/settings.json ~/.claude/settings.json.bak-manual
  ```

  Only that first pull needs the manual step, and only because the hook
  that would have done it arrives *in* that pull. From then on
  `~/.config/yadm/hooks/pre_pull` snapshots the file before every pull
  and `post_pull` reinstalls the shared half after, so no later pull
  needs a thought.

  From the pull after that one it is untracked and a pull genuinely
  cannot touch it. But on the receiving machine it is still tracked at
  the moment that commit arrives, so that pull deletes it if clean, or
  auto-stashes it if modified (`pull.rebase` and `rebase.autostash` are
  both on in the tracked git config). Reading "it is untracked now" and
  skipping the backup is exactly the mistake that loses the file.

  It had two writers — this repo and Claude Code itself, which rewrites
  it on `/model`, `/theme` and `/plugin` — and tracking it also
  published a personal model, effort level and plugin set from a public
  repo. The shared half is installed instead by
  `~/.local/bin/claude-settings-sync`, which bootstrap runs: it merges
  only `statusLine`, `theme` and the two hooks whose scripts this repo
  actually ships (`claude-notify`, `claude-name-session`), unions hook
  arrays rather than replacing them so existing hooks survive, and never
  writes `model`, `effortLevel`, `enabledPlugins`,
  `extraKnownMarketplaces` or `tui`. Run it by hand any time the
  statusline or hooks go missing.

  **On the first pull that carries this change, expect the file to
  disappear or to be stashed.** Untracking is a deletion as far as git
  is concerned, so a machine pulling it gets one of two behaviours,
  both verified: if its `settings.json` differs from the tracked copy,
  git stashes the change and the file survives (say `yadm stash drop`
  — the on-disk content was already what you wanted); if the file is
  clean, git simply **deletes** it. So on every other machine: back the
  file up before that pull, and run `claude-settings-sync` afterwards
  to reinstate `statusLine`, `theme` and the hooks. Anything personal
  in it (`model`, `effortLevel`, plugins) is yours to restore — the
  sync script deliberately will not write those.

  It deliberately does NOT write the herdr SessionStart hook. herdr
  generates `~/.claude/hooks/herdr-agent-state.sh` and owns its command
  and timeout, so a hardcoded copy here would restore the two-writers
  problem and go stale on the next herdr change — and a machine without
  herdr would get exit 127 every session. Run
  `herdr integration install claude` on machines that use herdr (below);
  merging is additive, so a machine that already has the hook keeps it.

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

## herdr remote (`hbox`)

`hbox` attaches this machine as a CLIENT to a herdr server running on
another box — a Mac mini, a Linux server, anything with sshd and herdr.
The wrapper lives in `.zshrc`; everything it needs to find the box does
not.

- [ ] **All three things `hbox` needs are UNTRACKED, deliberately.**
  Rule 9: the repo is public, so no hostnames, addresses or keys are in
  it. A freshly cloned machine has none of them and `hbox` just prints
  its usage line. Create them by hand:

  | File | Holds |
  | --- | --- |
  | `~/.zshrc.local` | `export HERDR_REMOTE_HOST="user@host"` |
  | `~/.ssh/config.d/NN-<host>.conf` | `Host` block naming the identity |
  | the private key it points at | the key itself |

  `.zshrc` sources `~/.zshrc.local` as its last step, and `.gitignore`
  already covers it. Confirm before writing a host into it:

  ```bash
  yadm check-ignore -v ~/.zshrc.local
  ```

- [ ] **`00-defaults.conf` sets `IdentitiesOnly yes` for `Host *`.**
  ssh then ignores agent-provided keys and offers ONLY what a matching
  `IdentityFile` names. A remote with no host block falls back to
  `~/.ssh/id_rsa` and fails with a bare
  `Permission denied (publickey,password,...)` that names no cause.
  Ask the resolver, never the files:

  ```bash
  ssh -G user@host | grep -E 'identityfile|identitiesonly'
  ```

- [ ] **Put every name you will use on the `Host` line, the raw IP
  included.** An mDNS name (`foo.local`) survives a DHCP lease change
  and is the better value for `HERDR_REMOTE_HOST`; the IP is what gets
  pasted into scripts. A name absent from the block silently skips the
  identity and lands you back on the failure above.

- [ ] **On a corp network a `.local` name or a private IP may not
  resolve at all.** Separate "cannot reach" from "reached, refused"
  before touching the config:

  ```bash
  ssh -o BatchMode=yes -o ConnectTimeout=8 user@host true
  ```

  `Permission denied` means sshd answered — an auth problem.
  A timeout means it did not — a network problem. A failed `ping`
  proves neither; ICMP is commonly filtered.

- [ ] **Client and server herdr versions must match.** `hbox` passes
  `--handoff`, which hands live panes over when an attach REPLACES a
  version-mismatched remote server. Two machines on different channels
  therefore replace each other's server on every attach. Put every
  machine sharing a remote server on the same channel — see the
  `herdr-preview` class above.

- [ ] **`--remote-keybindings=server` is load-bearing, not taste.** The
  default (`local`) makes the SERVER strip every custom command out of
  the client's keymap: bindings then do nothing at all, with no error.
  Keybindings are read ONCE at attach, so a client already running
  cannot be fixed — it has to reattach.

- [ ] **Remote Linux server: herdr is one static binary.** Assets are
  `herdr-linux-x86_64` and `herdr-linux-aarch64`. Where the channel
  setting belongs depends on what manages that box, and there are
  THREE cases, not two:

  | The box is | Put the channel |
  | --- | --- |
  | yadm-managed | in the `##template`, via the class |
  | managed by ANOTHER dotfiles repo | committed in THAT repo |
  | genuinely unmanaged | `herdr channel set` — it sticks |

  ```bash
  herdr channel set stable      # unmanaged boxes only
  herdr channel show
  herdr update
  herdr --version
  ```

  This page used to say `herdr channel set` sticks on any box yadm
  does not manage. **That is wrong for the middle case, and the middle
  case is the common one.** A repo that symlinks its config into place,

  ```bash
  ln -sf ../../dotfiles/config/herdr/config.toml ~/.config/herdr/config.toml
  ```

  makes `herdr channel set` write into that repo's WORKING COPY. It
  takes effect at once and looks durable, then a checkout, a reset or
  a fresh install script discards it in silence — after which
  `herdr update` walks the machine onto a different channel from its
  peer, and attach breaks with no obvious cause. Found 2026-08-19 on a
  devserver managed by a separate repo. The tell is one command:
  `readlink ~/.config/herdr/config.toml`. If it resolves into a repo,
  commit the value there instead.

  On a yadm-managed box use the class. `herdr channel set` writes into
  `config.toml`, and `yadm alt` regenerates that file from the
  template on every pull and wipes it.

- [ ] **A non-interactive ssh gets a minimal PATH**
  (`/usr/bin:/bin:/usr/sbin:/sbin`), which excludes `~/.local/bin`. So
  `ssh host 'command -v herdr'` reports nothing for a perfectly working
  install and reads as "not installed". Check the path directly:

  ```bash
  ssh host 'ls -l ~/.local/bin/herdr && ~/.local/bin/herdr --version'
  ```

## Verify

```bash
bash ~/test-dotfiles.sh        # full local suite
claude                          # starts without hook errors
type cd                         # alias for z (zoxide active)
```
