# Troubleshooting

Symptom-to-fix reference for recurring issues in this macOS dotfiles
environment.

## HTTPS git push fails with "Invalid username or token"

**Symptom:** `git push` (or `yadm push`) over an `https://` remote
fails with "Invalid username or token".

**Root cause:** Git Credential Manager was removed 2026-08, so the
`osxkeychain`-cached credential is stale. GitHub auth in this setup
is SSH-only via the 1Password agent.

**Fix:** Switch the remote to SSH. Never revert to HTTPS.

```bash
git remote set-url origin git@github.com:<owner>/<repo>.git

# yadm-managed repo
yadm remote set-url origin git@github.com:<owner>/<repo>.git
```

## `git push` rejected with publickey despite key in 1Password

**Symptom:** `git push` fails with a publickey error even though the
SSH key exists in 1Password and the agent is running.

**Root cause:** The 1Password key was added to GitHub as a
**signing** key only. GitHub keeps authentication keys and signing
keys as separate lists.

**Fix:** Add the same key under GitHub Settings, SSH and GPG keys,
New SSH key, with key type "Authentication Key" as well.

## SSH to GitHub ignores the 1Password agent

**Symptom:** SSH to `github.com` never offers the 1Password-backed
key.

**Root cause:** `IdentitiesOnly yes` in
`~/.ssh/config.d/00-defaults.conf` applies globally and makes ssh
skip agent-offered keys.

**Fix:** Set `IdentitiesOnly no` for the GitHub host specifically.

```bash
grep -A2 "^Host github.com" ~/.ssh/config.d/10-github-1password.conf
```

## Yazi opens with "Press Enter to continue with preset settings"

**Symptom:** Yazi shows "Press Enter to continue with preset
settings" on launch, and plugins are silently dead.

**Root cause:** Yazi major upgrades change the config schema (26.x
renamed the fetcher field `id` to `group`). A parse failure falls
back to presets instead of erroring.

**Fix:** Check the version output for the parse error, then update
`~/.config/yazi/yazi.toml` per each plugin's README.

```bash
yazi --version
```

A `test-dotfiles.sh` check now catches this regression.

## Commands prefixed with `env` silently do nothing

**Symptom:** Any command run as `env <command>` exits 0 with no
output.

**Root cause:** `~/.local/bin/env` is the uv installer's PATH
snippet, meant to be sourced, not executed. The culprit that made it
executable was the bootstrap's blanket `chmod +x ~/.local/bin/*`
(case closed 2026-08: the suite's env test caught the line re-arming
the trap during a bootstrap re-run). Bootstrap now chmods only
yadm-tracked scripts.

**Fix:**

```bash
chmod -x ~/.local/bin/env
```

Regression-tested in `test-dotfiles.sh`.

## herdr: "protocol version mismatch" after brew upgrade

**Symptom:** Cannot attach to a running herdr server after a brew
upgrade; herdr reports "protocol version mismatch".

**Root cause:** herdr's wire protocol refuses attach across any
version difference between client and server.

**Fix:** Finishing work via attach is impossible. Stop the server
and let it restart; layout and Claude panes resume natively via
`resume_agents_on_restore`.

```bash
herdr server stop
herdr
```

Daily maintenance notifies when an upgrade lands on a live server.

## zoxide `cd` -> `z` alias missing inside herdr panes

**Symptom:** The `cd` to `z` alias from zoxide is missing inside
panes opened by herdr.

**Root cause:** A stale `CLAUDECODE=1` is inherited when the herdr
server itself was started from inside a Claude Code shell.

**Fix:** `.zshrc` now decides aliasing by process ancestry. If hit
anyway, stop the server and restart herdr from a normal user shell,
never from inside a Claude session.

```bash
herdr server stop
herdr
```

## `fk` (pay-respects) hangs then times out

**Symptom:** `fk` hangs and eventually reports "Timeout while
executing command".

**Root cause:** zsh `share_history` let `fc -ln -1` return another
pane's command (e.g. a TUI), which pay-respects then re-executed.

**Fix:** `.zshrc` sets `inc_append_history` and `no_share_history`;
Atuin handles cross-pane search instead.

```bash
setopt inc_append_history
setopt no_share_history
```

## tmux/launchd daily maintenance never runs

**Symptom:** The daily maintenance agent does not run, even though
`launchctl load` reports success.

**Root cause:** `launchctl load` exits 0 even when the agent is
disabled in the launchd override database.

**Fix:** Enable and bootstrap explicitly; the repo's
`daily-maintenance-lib.sh` (`dm_load`) already does this.

```bash
launchctl enable gui/$UID/com.daily-maintenance
bash ~/install-daily-maintenance.sh
```

## VS Code disappeared after a cask upgrade

**Symptom:** `Visual Studio Code.app` is gone after
`brew upgrade --cask`.

**Root cause:** `brew upgrade --cask visual-studio-code --adopt` on
a self-updated app fails its checksum check after removal, leaving
nothing installed.

**Fix:** Reinstall clean; settings and extensions live in
`~/Library` and survive.

```bash
brew install --cask visual-studio-code
```

Prevention: maintenance uses `--greedy-latest`, which skips
`auto_updates` casks, and the test suite asserts plain `--greedy` is
never added.

## Zellij third-party plugin fails to load after 0.44

**Symptom:** A third-party Zellij plugin (e.g. zjstatus) fails to
load after upgrading to Zellij 0.44.

**Root cause:** Zellij 0.44 switched its wasm runtime from wasmtime
to wasmi, which broke plugin builds compiled before March 2026.

**Fix:** Use plugin builds from March 2026 or later. `zjstatus`
needs v0.23.0 or newer; the layout pins v0.24.0 by release URL.

## gitleaks negative test passes when it should fail

**Symptom:** A negative test meant to prove gitleaks catches a
leaked secret passes without gitleaks flagging anything.

**Root cause:** AWS documentation example keys (for example
`AKIAIOSFODNN7EXAMPLE`) are allowlisted by gitleaks' default config.

**Fix:** Canaries must look realistic. Assemble them at runtime so
no secret-shaped literal is ever committed to the fixture.

## Test fixtures hit the real yadm repo instead of a temp repo

**Symptom:** A test script or fixture reads or writes the real yadm
repo instead of its intended temp repo.

**Root cause:** The yadm `pre_commit` hook exports `GIT_DIR` and
`GIT_WORK_TREE`, which override any `git -C <path>` target.

**Fix:** Prefix fixture git calls to unset both variables.

```bash
env -u GIT_DIR -u GIT_WORK_TREE git -C /path/to/fixture status
```

See `test-dotfiles.sh` Test 15.

## Two Claude/agent sessions commit each other's staged files

**Symptom:** A `yadm commit` from one session includes files staged
by a different, unrelated session.

**Root cause:** All sessions share one yadm index; `yadm commit`
sweeps everything currently staged, regardless of which session
staged it.

**Fix:** Check staged files before every commit; keep one committer
per repo at a time.

```bash
yadm diff --cached --name-only
```

## Neovim plugins error with "attempt to call a nil value" (API missing)

**Symptom:** A plugin (e.g. neo-tree) throws a `vim.schedule` callback
error; the stack ends in an `nvim_*` API call that does not exist.

**Root cause:** nvim runs a stale nightly while plugins update daily.
`has("nvim-0.13")` is true for every 0.13-dev build, so plugins call
APIs that landed in later nightlies. In August 2026 the deeper cause
was bob's git-dev build moving its data dir to
`~/Library/Application Support/bob`: a half-finished install there
wedged `bob install nightly` ("Couldn't find bob.json") for a month.

**Fix:** Remove the half-installed `nightly/` dir (and stray tarball)
from the NEW data dir, reinstall, and make sure PATH prefers the new
`nvim-bin`:

```bash
bob install nightly && bob use nightly
command -v nvim && nvim --version | head -1
```

The suite's "Neovim boots headless" check and the maintenance bob task
status are the canaries.
