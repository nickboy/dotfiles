# herdr Setup Guide (Mac + Remote Linux)

Dual-machine herdr architecture for Claude Code sessions. Written for
setting up a new work laptop (Mac) and a remote Linux work server.
Facts marked **verified** were tested live on this setup (herdr 0.7.5);
items marked **⚠ verify** need a one-minute check on setup day.

## Architecture

```text
Mac (Ghostty)
├─ tab 1: herdr                    → local Claude agents (local server)
├─ tab 2: herdr --remote <host>    → remote Claude agents (Linux server)
└─ tab 3: tmux                     → general dev (unchanged, escape pod)

Fallback from any device: ssh <host> → herdr   (client/server are the
same binary on that machine — can never version-skew)
```

Rules learned the hard way:

- **Never start the herdr server from a Claude Code session.**
  Panes inherit the server's environment; a Claude-started server
  leaks `CLAUDECODE=1` into every pane and kills zoxide/`cd` (the
  .zshrc guard fires for user shells). `.zshrc` now clears a stale
  flag inside herdr panes, but the server should still be started by
  a human running plain `herdr` from a login shell, or auto-started
  by the first attach. CLAUDECODE was merely the leaked variable that
  got CAUGHT — a tool-shell server keeps handing every future pane
  its whole polluted environment. (**verified** — it happened.)
- **No nesting**: herdr inside a herdr pane is blocked by design
  (`HERDR_ENV=1`). Run remote attach in its own Ghostty tab.
- **Version discipline**: the wire protocol refuses attach on ANY
  client/server version mismatch. Mac and Linux must run the same
  version and upgrade together (see Upgrades below). The `ssh` +
  local `herdr` fallback always works regardless of skew.
- herdr's prefix is `ctrl+a` — the same as remote tmux. Inside a
  herdr pane, an inner tmux never sees the prefix. Reach remote tmux
  from a plain Ghostty tab instead. (**⚠ verify** whether pressing
  `ctrl+a` twice forwards a literal prefix.)

## Install

Mac — self-updater managed, NOT Homebrew (owner call 2026-08-05:
upstream disables `herdr update` for brew installs, and only the
self-updater supports live handoff; same class as ghostty@tip/bob):

```bash
curl -fsSL https://herdr.dev/install.sh | sh   # -> ~/.local/bin/herdr
```

`~/.local/bin` precedes `/opt/homebrew/bin` in PATH, so never install
the brew formula alongside — it would shadow-race this binary.

Linux (**⚠ verify** the official installer URL on setup day):

```bash
curl -fsSL https://herdr.dev/install.sh | sh
herdr --version    # MUST match the Mac version
```

Linux plugin dependencies (install first): `bun`, `fzf`, `jq`,
`python3`, `cargo`, `nvim`, and `television` >= 0.15 via
`cargo install television` — termscope's build step upgrades tv via
Homebrew when missing (**verified** on Mac: it silently bumped
0.14.4 → 0.15.9), and on Linux without brew it aborts instead.

## Config

Nothing to write on a new machine — it ships with the dotfiles:

- `~/.config/herdr/config.toml##template` (tracked): `yadm alt`
  generates `config.toml` on clone/pull. Only the `[experimental]`
  block branches per OS (kitty graphics + CJK IME are Darwin-only).
- Toast delivery is `terminal` (**verified the hard way**): the client
  asks its outer terminal (Ghostty) to post the banner. `system` looks
  right on paper but macOS only has Ghostty registered in Notification
  Center — herdr's system path (terminal-notifier/osascript) gets
  silently dropped. `terminal` covers every topology: local, --remote
  (client is local Ghostty), and ssh+herdr (OSC rides SSH back).
  Banners appear only while Ghostty is unfocused (Ghostty's policy).
- Reload after changes: `herdr server reload-config` (edit the
  template, run `yadm alt`, then reload).

## Who reads which config (--remote)

Config reading SPLITS between client and server under `herdr
--remote` (source-verified against 0.7.5):

| Side | What it reads |
| --- | --- |
| Client (Mac) | `[keys]`, `[ui.toast]`, `[ui.sound]`, `[remote]` |
| Server (remote) | theme/terminal/session/worktrees/experimental + plugins |

Practical consequences:

- **Editing keybinds on the remote does nothing under `--remote`.**
  `--remote-keybindings` defaults to `local`: the client's `[keys]`
  always wins. Override with `--remote-keybindings=server` to use
  the remote's `[keys]` instead.
- **Custom commands NEVER fire from a client-supplied keymap**
  (source-verified 0.8.0): the server strips every `[[keys.command]]`
  when parsing client keybindings (`parse_client_keybindings` runs
  `config.keys.command.clear()`; a unit test asserts it — deliberate
  policy so a client config can't inject shell onto the server host).
  So bindings like `prefix+shift+o` (claude-copy-last) are dead under
  a default `--remote` attach no matter which machine's config has
  them — attach with `--remote-keybindings=server` (harmless here:
  yadm ships the same config everywhere). When they do fire, the
  shell spawns IN THE SERVER PROCESS with stdio null'd: `pbcopy` sets
  the server's clipboard, stderr goes nowhere. `claude-copy-last`
  therefore writes OSC 52 to the pane's pty and toasts failures via
  `herdr notification show`. herdr silently drops clipboard writes over
  192 KiB decoded (`MAX_CLIPBOARD_BYTES`); the script guards at 190 KiB
  and toasts instead.
- **A stale second client silently steals every clipboard copy**
  (**verified the hard way, 2026-08-08 — cost most of a day**).
  `ClipboardWrite` goes to `foreground_client_id` ONLY —
  `send_to_foreground_client`, deliberate upstream ("clipboard writes
  are client-local side effects... not broadcast"). So a forgotten
  `herdr` left attached on the SERVER host keeps foreground and every
  copy lands on the server's pasteboard while your `--remote` client
  gets nothing. There is no error, no toast, no log line — the copy
  succeeds, just onto the wrong machine.
  Symptom: `prefix+shift+o` "does nothing", but `pbpaste` ON THE SERVER
  shows the text. Diagnosis, since no CLI exposes the client list:

  ```bash
  grep -oE 'client (connected|disconnected) client_id=[0-9]+' \
    ~/.config/herdr/herdr-server.log |
    awk '{split($3,a,"="); if($2=="connected") s[a[2]]=1; else delete s[a[2]]}
         END {for (k in s) printf "%s ", k; print ""}'
  ```

  More than one id = the bug is live. Fix: `kill` the stale client's
  process (a detach — the server and every pane survive);
  `promote_latest_remaining_client` hands foreground back. Confirm with
  a sentinel: set the server clipboard, write one OSC 52 to a pane tty,
  and check that the server's clipboard is UNCHANGED — that proves the
  write went to the remote client instead. Runtime `foreground_client_id`
  is otherwise only visible via `HERDR_LOG=herdr=debug`, which needs a
  server restart and therefore kills every pane.
- **A locally-bound plugin key goes silent if the remote lacks the
  plugin.** Plugin actions execute server-side (e.g. `prefix+e` →
  reviewr), so every plugin must be installed on BOTH ends, pinned
  to the SAME `--ref` SHAs — mirror the block in Plugins below onto
  the remote machine.
- **Client-side config is attach-time, full stop.** Everything the
  client reads (`[keys]`, `[ui.toast]`, `[remote]`) is read once at
  attach; `server reload-config` only covers the server-side half.
  `[ui.sound]` is the lone exception that hot-reloads. After changing
  any client-side setting, detach and reattach every client.

## Plugins (each machine, SHA-pinned)

```bash
herdr plugin install --yes paulbkim-dev/vim-herdr-navigation \
  --ref 820d48f5d9c9a7dece6a4bebfa3982ec30bbfbb7
herdr plugin install --yes andrewchng/herdr-sessionizer \
  --ref 20827358a8da57b83d479cf899909bbf11919541
herdr plugin install --yes iurysza/termscope \
  --ref cbc6da8103c263343b7082e27e804cc91312f944
herdr plugin install --yes NathanFlurry/herdr-plugin-jj-workspace \
  --ref a9f1d3bcdaa2354e336a5173da85cbe4970c0f2e
herdr plugin list
```

Version-control boundaries (**verified**):

- `plugins/github/` = build artifacts (bun node_modules, cargo
  target) — in `.yadmignore`, reinstall with the lines above
- `plugins/config/` = plugin settings — yadm-tracked
- Supply-chain hardening option: fork each repo and install
  `nickboy/<repo> --ref <SHA>` (identical behavior); worth reviewing
  termscope's `scripts/install-dependencies.sh` before install since
  it touches the package manager

Keybindings live in the main config (already set): `ctrl+hjkl`
navigation, `prefix+f` / `prefix+shift+f` sessionizer,
`prefix+u` / `prefix+shift+u` termscope (prefix-based on purpose —
bare `ctrl+e/a` would steal readline keys), `prefix+shift+j` /
`prefix+alt+j` jj workspaces. The jj **remove** action stays unbound:
it runs `jj workspace forget` + `rm -rf` (untracked files gone) —
action menu only.

Sessionizer roots are machine-specific
(`~/.config/herdr/plugins/config/sessionizer/config.toml`, tracked):
this Mac uses `~/src`, `~/Workspace`, `~` with `git_only`. On a new
machine with different project roots, either keep the same directory
names or convert that config to a `##template` too. Known limits
(**verified**): roots list children only (`~` itself and hidden dirs
like `~/.claude` can never be candidates), no blacklist, preview is
hard-coded `bat`/`ls`.

## Claude Code integration (each machine)

```bash
herdr integration install claude
yadm diff .claude/settings.json   # review, then commit if it changed
```

**Verified**: it merge-edits settings.json and preserves existing
hooks (claude-notify, claude-name-session) and the statusline. On
0.7.x it also re-sorted every key (53-line diff noise) and dropped
the trailing newline — 0.8.0 fixed both upstream (#2066: key order
and formatting preserved). One fixup likely still needed after a
(re)write: the hook command uses a hardcoded `/Users/...` path —
change it to `"$HOME/..."` (verify on the next reinstall; the
changelog doesn't mention the path). The generated hook script
(`~/.claude/hooks/herdr-agent-state.sh`) is a machine artifact — do
not track; rerun the integration command to regenerate.

## Notifications: who does what

| Path | Behavior |
| --- | --- |
| herdr pane (local or remote) | herdr agent engine → Ghostty banner |
| Ghostty direct / tmux / SSH+tmux | claude-notify (OSC 9/777) as before |

Toasts fire on agent transitions to done/blocked; the ACTIVE tab is
suppressed by design — staring at a finishing agent never banners.
Sounds for background state changes are on by default (`[ui.sound]`).

Troubleshooting no-banner (learned live):

1. **The client reads toast config at attach** — `server
   reload-config` is not enough. After changing `[ui.toast]`, detach
   and reattach every client.
2. Client-side breadcrumb: `herdr-client.log` logs "received terminal
   toast notification from server". Line present but no banner →
   emission side (TERM detection / terminal permission). Line absent →
   the server never sent it (delivery off, wrong config, or the
   active-tab / focused suppressions).
3. Terminal delivery silently no-ops when the client's TERM /
   TERM_PROGRAM is not a recognized terminal — on ssh+herdr check
   `echo $TERM` is still `xterm-ghostty` (a profile that rewrites it
   to xterm-256color kills banners with no error).
4. macOS: only apps registered in Notification Center can post —
   check `defaults read com.apple.ncprefs apps`. On this Mac only
   Ghostty is registered, which is why delivery is `terminal`.

**Verified**: herdr consumes pane OSC 9/777 rather than forwarding
them (the OSC 9 payload even pollutes the agent-progress display), so
`claude-notify` stands down inside herdr panes (guard at the top of
the script). Ghostty's `notify-on-command-finish` also never fires
inside herdr panes (OSC 133 is consumed) — expected, covered by
toasts.

## Session titles on tabs

Free with the dotfiles: `claude-name-session` mirrors the Claude
session title onto the herdr tab (`herdr tab rename $HERDR_TAB_ID`) —
the equivalent of the old tmux window rename. New sessions get the
`project/branch` default; resumed sessions mirror their real title.
Mid-session `/rename` syncs on the next resume (no hook event exists).

## Remote attach checklist (same on macOS and Linux)

Nothing below is OS-specific — it is the same on a Mac mini, a Linux
box, or a work server. Use this when setting up a new pair.

**Server** (the box being attached to): herdr installed at the SAME
version as the client; every plugin installed that any key binds to,
since plugin actions execute server-side; `config.toml` generated from
the dotfiles (`yadm alt`) — under the flag below it is the server's
`[keys]` that actually runs.

**Client** (the laptop you sit at): herdr installed, same version;
attach with `--remote-keybindings=server`; and be the ONLY attached
client.

Two settings are load-bearing and neither lives in `config.toml`:

1. **`--remote-keybindings=server` on every attach.** There is no
   config key for it (`[remote]` holds only `manage_ssh_config`), and
   the internal `HERDR_REMOTE_KEYBINDINGS` env var must not be set by
   hand — the client also uses its presence to decide whether it is a
   remote process. Use the tracked `hbox` helper in `.zshrc`, which
   bakes in the flag and reads the host from `$HERDR_REMOTE_HOST` in
   the untracked `~/.zshrc.local` (this repo is public, so no hosts in
   it):

   ```bash
   # ~/.zshrc.local on each client machine
   export HERDR_REMOTE_HOST='user@work-server'
   ```

   Then `hbox` attaches, or `hbox user@otherbox` for a one-off.
2. **Exactly one attached client**, or clipboard copies go to whichever
   client holds foreground (see the stale-client bullet above).

Clipboard, per OS: the copy is delivered to the CLIENT, so the client's
OS is what matters and both are handled natively. On the SERVER the
script also does a local copy as a convenience — `pbcopy` on macOS,
`wl-copy`/`xclip` on Linux — and when none exists (a headless Linux
server) that step is skipped without blocking the OSC 52 delivery that
actually reaches you.

## Daily entrypoints

- Local: run `herdr` in a Ghostty tab (auto-starts the server).
- Remote: `hbox` (see the checklist above), which expands to
  `herdr --remote=<host> --remote-keybindings=server --handoff`.
  herdr's generated SSH config includes `~/.ssh/config` first, so
  ProxyJump/ControlMaster/1Password agent settings all apply.
- The client does NOT auto-reconnect after a network drop (it exits
  with a reattach hint). A retry wrapper for `.zshrc`, **⚠ verify
  first** that a deliberate `prefix+q` detach exits 0 (detach once,
  pull the network once, check `$?` both times):

```bash
hbox() {
  while true; do
    # --handoff: if the attach replaces the remote server (version
    # sync), live panes are handed over instead of killed;
    # server keybindings: [[keys.command]] is stripped from client
    # keymaps, so custom commands need the server's own keymap
    herdr --remote user@box --handoff --remote-keybindings=server "$@" && break
    print "connection lost — retrying in 2s (Ctrl-C to stop)"
    sleep 2
  done
}
```

- Fallback from anywhere: `ssh <host>` then plain `herdr` — same
  binary, same version, always attaches.

## Upgrades (Mac automatic, remote self-syncs)

The formula is unpinned by owner decision: the Mac side is upgraded
by the daily maintenance run, which detects a bump landing on a live
server and sends a notification (restart when convenient — the wire
protocol refuses attach across versions).

The REMOTE side follows AUTOMATICALLY (source-verified): every
`herdr --remote <host>` attach checks the remote binary's version
string against the local one and installs/replaces it on mismatch.
`--handoff` decides what happens to live remote panes during that
replacement:

- without it (default): old server stops → panes killed → snapshot
  restore + `claude --resume` rebuilds layout and conversations, but
  running processes (builds, tests, tails) start over
- with it: the old server hands live PTYs/processes to the new one —
  panes keep running (experimental; in-flight API requests and
  subscription streams may still drop and need a retry)

So the whole flow is: Mac auto-upgrades daily; next remote attach
syncs the box. Always attach with `--handoff` (the hbox wrapper
below bakes it in).

Mac upgrades (self-updater managed since 2026-08-05): run
`herdr update --handoff` when the in-app version check nags — live
handoff replaces the local server WITHOUT killing panes (in-flight
API requests may need a retry). Daily maintenance no longer touches
herdr at all (it left the Brewfile); its strand-detection guard stays
as a harmless no-op. Never run `herdr --remote` OR `herdr update`
from non-interactive automation: replacing a running server requires
an interactive confirmation and errors otherwise.

Manual fallback (or first install):

```bash
ssh <host> 'curl -fsSL https://herdr.dev/install.sh | sh'
herdr --version && ssh <host> 'herdr --version'   # must match
```

Then restart each server at a convenient moment
(`herdr server stop`; next attach restores the layout and
`claude --resume`s the agent panes — `resume_agents_on_restore`).

**Before any server stop**: it kills every pane, not just agents.
Agent panes come back with their conversations; NON-agent panes
(dev servers, `tail -f`, running downloads) restore as a fresh shell
in the right directory only. Scan the sidebar and wind those down
first.

## Day-1 verification checklist

1. LazyVim diagnostics show colored undercurls in a herdr pane
2. Shift+Enter inserts a newline in Claude Code
3. `prefix+?` — walk the keymap, look for conflicts
4. Remote: yank in a remote nvim → lands in the Mac clipboard
   (OSC52 through the client — **⚠ verify**)
5. Remote: let an agent block → macOS notification banner appears
6. `hbox` exit-code semantics (see above)
7. tmux + yazi image preview still works (general dev untouched)

## Rollback

`brew unpin herdr && brew uninstall herdr` (Mac), remove the Linux
binary, `herdr integration uninstall claude` on both ends (**⚠
verify** it removes only its own hook entries), revert the trial
branch. tmux was never touched; Zellij retires only if herdr
graduates.
