# Claude Code tooling

Five small tools that make Claude Code usable across two machines and
inside a multiplexer. Everything here is bash + `jq`, installed by
`yadm bootstrap`, and covered by the test suite.

| Tool | What you get |
| --- | --- |
| [`ccl`](#ccl--copy-a-reply) | Copy a Claude reply as raw markdown |
| [`claude-settings-sync`](#claude-settings-sync) | Shared settings without shared secrets |
| [`hbox`](#hbox--remote-attach) | Remote attach that keeps your keybindings |
| [pull hooks](#pull-hooks) | A pull leaves the machine ready |
| [statusline switches](#statusline-switches) | One script, per-machine segments |

---

## `ccl` — copy a reply

The Claude app has a per-message copy button; a terminal has a screen.
`ccl` reads the reply out of the session transcript instead, so you get
the **original markdown** — unaffected by scrollback, line wrapping,
colour or which terminal you are in.

```bash
ccl              # latest reply → clipboard
ccl -n 2         # the one before it (the latest is often a question back)
ccl | glow       # piped: raw markdown on stdout
ccl > notes.md
```

Bound to `prefix+O` in tmux and `prefix+shift+O` in herdr.

**How it picks the transcript.** Three tiers, each falling through to
the next, so a missing tier degrades to the previous behaviour rather
than to a wrong answer:

1. **The sessions in this pane, ranked by who you spoke to last.** The
   statusline records one marker per (pane, session) under
   `~/.cache/claude-pane/`, and `ccl` ranks them by the last *human*
   turn in each transcript.
2. **herdr's own registration**, which is right whenever a pane holds a
   single session.
3. **The newest transcript** for the current directory, walking up from
   `$PWD` — for plain shells and tmux.

Tier 1 exists because herdr keeps only ONE session per pane and will
not replace it when a second one starts, so a background job — which
inherits the pane from wherever it was launched — is invisible to it.
Without tier 1, `ccl` copied that pane's *first* session perfectly, and
the wrong conversation arrived in your clipboard.

Ranking is by last human turn rather than by file mtime because a
session can write for hours with nobody speaking to it. Measured on a
live pane: the foreground session's transcript was the more recently
written, while its last human turn was eleven hours older than the
background job's sitting beside it. mtime picked the stale one.

**One thing it cannot know, and says so.** `ccl` answers "which
conversation belongs to this pane". Claude Code's agent view can render a
conversation that belongs to *another* pane — a background job launched
elsewhere — and then the inherited pane id, the process tree and herdr's
registration all agree with each other and all three are wrong about what
you are looking at.

So after choosing, `ccl` checks the pane's rendered screen against what it
picked. If they disagree it says so:

```text
copied 333 chars from 3bcaa0fe — WARNING: this pane is showing 8f485a02
```

This is a verifier, never a selector: it cannot change the answer, only
describe it, so a screen it cannot read costs a missing warning rather than
a wrong copy. Matching is restricted to **assistant text blocks**, because
agents relay each other's replies inside tool arguments and a whole-file
search names everyone in the relay instead of the author.

**It tells you what it did.** Every copy reports the session, how it
was chosen, and how long ago you last spoke there:

```text
copied 2805 chars from 319ca5df (pane, 1 in pane) · you last spoke 7m ago
```

Under the keybinding this arrives as a notification, because that is
the only channel a detached command has. It also says `no human turn in
this pane` when nothing there has ever been spoken to and the choice
had to be made on weaker evidence, and names the project directory when
the conversation comes from one you are not currently in.

**When nothing happens.** Under a keybinding the script has no stdout,
so failures surface as a herdr notification: no transcript for this
directory, no message that far back, or a reply too large for the
clipboard (herdr silently drops writes over 192 KiB).

---

## `claude-settings-sync`

`~/.claude/settings.json` has two writers — this repo, and Claude Code
itself, which rewrites the file whenever you use `/model`, `/theme` or
`/plugin`. So the file is **untracked**, and this script installs only
the half that is genuinely shared.

| Written | Never written |
| --- | --- |
| `statusLine`, `theme`, our hooks | `model`, `effortLevel`, plugins, `tui` |

`theme` is *seeded*, not asserted: it is written only on a machine
that has none, so a theme you chose yourself is left alone. The rest
are re-applied every run, because a stale `statusLine` or hook path
actually breaks something.

The rule: **does this repo ship the thing the key points at?** Your
model choice, effort level and plugin set stay yours, per machine. Two
machines can want different models — that is the normal case, not a
conflict to resolve.

```bash
claude-settings-sync           # install/repair the shared half
claude-settings-sync --check   # report only; exit 1 if something is missing
```

Runs automatically from `yadm bootstrap` and after every `yadm pull`.
Safe to run any time: it merges rather than overwrites, unions hook
lists so hooks you added elsewhere survive, refuses to touch a file it
cannot parse, and takes a timestamped backup before any write.

It deliberately does **not** write herdr's SessionStart hook — herdr
generates that script and owns it. If the entry exists but the script
is gone, the script says so and tells you to run
`herdr integration install claude`, rather than repairing it and
risking a duplicate entry.

---

## `hbox` — remote attach

```bash
hbox                 # uses $HERDR_REMOTE_HOST
hbox user@otherbox   # one-off
```

Set the host per machine in the untracked `~/.zshrc.local`:

```bash
export HERDR_REMOTE_HOST='user@host'
```

`hbox` exists because the flag it carries is **load-bearing**:

```bash
herdr --remote=<host> --remote-keybindings=server --handoff
```

Without `--remote-keybindings=server`, the server strips every custom
command out of the client's keymap — a client config must not inject
shell onto the server host — so `prefix+shift+O` and every plugin
binding do nothing at all, with no error. Keybindings are read once at
attach, so a client already running cannot be fixed; it has to
reattach.

**One attached client at a time.** herdr delivers a clipboard write to
the foreground client only, so a forgotten `herdr` left running on the
server host silently swallows every copy. If copies stop arriving,
check for a second client:

```bash
grep -oE 'client (connected|disconnected) client_id=[0-9]+' \
  ~/.config/herdr/herdr-server.log |
  awk '{split($3,a,"="); if($2=="connected") s[a[2]]=1; else delete s[a[2]]}
       END {for (k in s) printf "%s ", k; print ""}'
```

More than one id and the bug is live.

**One id is not proof you are fine.** A long-lived server that has seen
clients come and go can end up with no *foreground* client while one is
still connected, and every clipboard write is then dropped silently —
the diagnostic above still reports a single id. If copies vanish with
one client listed, **detach and reattach**. Delivery resumes.

---

## Pull hooks

`yadm pull --rebase` should leave the machine ready with nothing to
remember, so two hooks do the remembering:

- **`pre_pull`** snapshots `~/.claude/settings.json` (keeps `model`,
  plugins, effort level)
- **`post_pull`** runs `claude-settings-sync` (restores statusline,
  theme, hooks)

Backups land beside the file as `settings.json.bak-<timestamp>-<pid>`,
pruned to the last three and ignored by git.

**One manual step, once per machine.** Before the *first* pull that
carries the untracking change, back the file up by hand:

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak-manual
```

Full runbook: [work-machine-checklist.md](work-machine-checklist.md).

Untracking is a deletion as far as git is concerned, so that pull
deletes the file if it is clean, or auto-stashes it if you have local
changes. `pre_pull` cannot help, because it arrives *in* that pull.
Every pull after it is automatic.

A fresh machine needs none of this: `yadm clone` + `yadm bootstrap`,
and the file is built from scratch.

### Getting it back

```bash
ls -t ~/.claude/settings.json.bak-*            # newest first
cp ~/.claude/settings.json.bak-<ts>-<pid> ~/.claude/settings.json
```

If the file was deleted while clean, there was no local change to lose
— it matched the last tracked copy, so git still has it:

```bash
yadm show <sha>:.claude/settings.json > ~/.claude/settings.json
```

Use a commit from before the untracking. Then run
`claude-settings-sync` to reinstate the shared half.

---

## Statusline switches

The statusline is one script on every machine; only its segments
differ. Defaults show everything. To hide segments, write the untracked
`~/.config/claude-statusline/config.sh`:

```bash
SHOW_COST=0          # meaningless under enterprise billing
SHOW_BURN=0
SHOW_RATE_LIMITS=0   # absent from the payload on Bedrock/Vertex
SHOW_HERDR=0         # skip herdr/herddeck side effects
```

Omit the file and everything stays on.

The statusline also mirrors your session name onto the herdr tab, so
`/rename` shows up where you can see it. It will not overwrite a tab
you named by hand: it reclaims only labels a script recorded, or
herdr's own numeric default.

**Known limit.** Two sessions sharing one pane both believe they own
its tab, and will alternate the label about once a minute. Nothing is
broken — rename one of the sessions, or move them into separate tabs.

---

## Requirements

`jq` (in the Brewfile) for everything; `herdr` only for the herdr-specific
paths, all of which are guarded. macOS uses `pbcopy`; Linux falls back to
`wl-copy` or `xclip`, and if neither exists the copy still reaches a
remote client over OSC 52.

## Related

- [herdr-setup.md](herdr-setup.md) — two-machine herdr setup
- [work-machine-checklist.md](work-machine-checklist.md) — deploying onto
  a machine that already has its own config
- [upgrade-watch.md](upgrade-watch.md) — the upstream internals these
  tools depend on, and what breaks if they change
