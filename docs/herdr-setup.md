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

Mac:

```bash
brew install herdr && brew pin herdr   # pinned: upgrades are manual
```

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
hooks (claude-notify, claude-name-session) and the statusline. Two
fixups it needs every time it (re)writes: the hook command uses a
hardcoded `/Users/...` path (change to `"$HOME/..."`), and the file
loses its trailing newline. The generated hook script
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

## Daily entrypoints

- Local: run `herdr` in a Ghostty tab (auto-starts the server).
- Remote: `herdr --remote user@host`. **Verified from CLI help**:
  `--remote-keybindings local` is the default — your local muscle
  memory follows you. herdr's generated SSH config includes
  `~/.ssh/config` first, so ProxyJump/ControlMaster/1Password agent
  settings all apply.
- The client does NOT auto-reconnect after a network drop (it exits
  with a reattach hint). A retry wrapper for `.zshrc`, **⚠ verify
  first** that a deliberate `prefix+q` detach exits 0 (detach once,
  pull the network once, check `$?` both times):

```bash
hbox() {
  while true; do
    herdr --remote user@box "$@" && break
    print "connection lost — retrying in 2s (Ctrl-C to stop)"
    sleep 2
  done
}
```

- Fallback from anywhere: `ssh <host>` then plain `herdr` — same
  binary, same version, always attaches.

## Upgrades (both ends together, always manual)

Daily maintenance never touches herdr (`brew pin`, enforced by a
test-suite assertion). To upgrade, do both machines in one sitting:

```bash
brew unpin herdr && brew upgrade herdr && brew pin herdr
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
