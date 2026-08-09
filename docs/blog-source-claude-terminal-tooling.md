# Building Claude Code tooling for a multiplexer that wasn't built for it

Source notes for a write-up. Everything below was built and verified on
a real two-machine setup (Mac mini as herdr server, MacBook as client)
across PRs #80–#87 of a public dotfiles repo. Every claim marked
**verified** was tested against a running system or read out of the
installed binary, not inferred.

---

## 1. The problem: a terminal has no copy button

The Claude desktop app has a per-message copy button. A terminal has a
screen. Copying an agent's reply meant dragging a mouse across wrapped,
coloured, scroll-shifted text and getting back something you had to
clean up by hand.

The usual fix is terminal-side: OSC 133 prompt marks let you jump
between shell prompts. That fails here for a structural reason — Claude
Code is a full-screen TUI, and OSC 133 is a *shell* protocol. There are
no prompt boundaries inside a TUI to jump between.

**The insight that unlocked it:** Claude Code writes every message to
`~/.claude/projects/<slug>/<session-id>.jsonl` as it goes. The original
markdown is already on disk. Read it from there and you get text that
is immune to scrollback, wrapping, theme and terminal emulator — and it
is the *source* markdown, not the rendered approximation.

```bash
ccl          # copy the latest reply
ccl -n 2     # the one before it — useful when the last message is a question
ccl | glow   # or pipe it; raw markdown on stdout when not a tty
```

Roughly 100 lines of bash and `jq`. Three details that turned out to
matter more than the extraction itself:

- **Filter `isSidechain`.** Subagent traffic is also `type: assistant`.
  Without the filter you copy a subagent's internal monologue.
- **Multiple text blocks per turn.** A single turn holds several text
  blocks (status notes between tool calls). Join them into one message,
  but let `-n` step through *messages*, not blocks.
- **Which transcript?** Originally "newest file in the project
  directory". See §5 — that one was wrong in a way that took a live bug
  to expose.

**Prior art check:** a survey of the ecosystem found session viewers,
bulk exporters and resume pickers — but nothing that copies *one*
message to the clipboard. The nearest neighbours are generic JSONL
parsing libraries, which leave you writing the entire selection,
filtering and clipboard logic anyway.

---

## 2. Three bugs stacked between the keypress and the clipboard

Binding it to `prefix+shift+O` in [herdr](https://herdr.dev) (an
agent-aware multiplexer) worked locally and did nothing at all over a
remote attach. Three independent causes, each hiding the next.

### 2.1 The keymap strip (verified in v0.8.0 source)

Under `herdr --remote`, the client ships its `[keys]` config to the
server, and the server runs:

```rust
config.keys.command.clear();
```

Every `[[keys.command]]` is deliberately removed — a client config must
not be able to inject shell commands onto the server host. A unit test
upstream asserts it. **No custom binding can ever fire from a default
remote attach**, regardless of which machine's config defines it.

The fix is a launch flag, not a config key: `--remote-keybindings=server`.
There is no config file option for it, and the internal env var must not
be set by hand — the client also uses its presence to decide whether it
*is* a remote process.

### 2.2 The clipboard went to the wrong machine

Custom commands spawn **in the server process** with stdio nulled. So
`pbcopy` set the *server's* clipboard, and any failure was silent.

The fix rides the multiplexer's own pipeline: write OSC 52 to the pane's
pty, and herdr forwards it to the attached client's native clipboard.
Two caps worth knowing: writes over **192 KiB decoded** are dropped
silently (`MAX_CLIPBOARD_BYTES`), and delivery goes to **one** client.

### 2.3 A stale client two rooms away

Even with both fixed, copies kept landing on the server. Cause: clipboard
writes go to `foreground_client_id` *only* — deliberate upstream, since
a clipboard is a client-local side effect. A forgotten `herdr` session
left attached on the server host had foreground, and swallowed every
copy. No error, no toast, no log line: **the copy succeeded, just onto
the wrong machine.**

Diagnosis, since no CLI exposes the client list:

```bash
grep -oE 'client (connected|disconnected) client_id=[0-9]+' \
  ~/.config/herdr/herdr-server.log |
  awk '{split($3,a,"="); if($2=="connected") s[a[2]]=1; else delete s[a[2]]}
       END {for (k in s) printf "%s ", k; print ""}'
```

More than one id means the bug is live.

**The generalisable lesson:** a feature can fail at the *keybinding*,
the *transport* and the *routing* layers independently, and each layer
reports success. When the symptom is "nothing happened", the useful
question is not "what broke" but "how far did it get".

---

## 3. Config that two machines can share without fighting

`~/.claude/settings.json` had **two writers**: the dotfiles repo, and
Claude Code itself (`/model`, `/theme`, `/plugin` rewrite it). Tracking
it meant the two machines overwrote each other's model preference on
every pull, and a public repo published a personal plugin set.

The split that worked:

| Kind | Examples | Where it lives |
| --- | --- | --- |
| Infrastructure | `statusLine`, `theme`, hooks | tracked; script-installed |
| Personal | `model`, `effortLevel`, plugins | untracked; never written |

The rule for deciding: **does this repo ship the thing the key points
at?** `statusLine` runs our script; `theme` resolves to our tracked
theme file; hooks are our scripts. `tui: fullscreen` points at nothing
we ship — that is taste, and a cloner should not inherit it.

Result, verified live: the Mac mini keeps `claude-fable-5[1m]`, the
MacBook keeps `opus[1m]`, and neither overwrites the other. They wanted
different models all along, which is the clearest evidence the file
should never have been shared.

### Two traps in the merge

**`jq`'s `*` replaces arrays.** A deep merge looks like the obvious
implementation, and it would have silently deleted any hook a third
party already had:

```text
base:   {"hooks":{"SessionStart":[{"a":1}]}}
inject: {"hooks":{"SessionStart":[{"b":2}]}}
result: SessionStart == [{"b":2}]   ← {"a":1} is gone
```

Hook arrays are unioned per event with an order-preserving dedup keyed
on `(matcher, sorted commands)`, so foreign hooks survive, keep their
position, and re-runs stay idempotent.

**Untracking a file is a deletion.** This one bites everyone once.
Committing `git rm --cached` means the *next pull on every other
machine* deletes the file (if clean) or auto-stashes it (if modified).
`.gitignore` does not protect it — gitignore only governs files git is
not already tracking. It happened three times during this work, always
recoverable, never silently.

The fix is to make the pull self-sufficient rather than to document a
step people will skip. Multiplexer/VCS hooks beat a `bootstrap` command,
because bootstrap is something you have to *remember*:

- `pre_pull` snapshots the file before every pull
- `post_pull` reinstalls the shared half after

Exactly one manual step remains, once per machine — and it is
unavoidable for a lovely reason: the hook that would have automated it
arrives *in* the pull it needed to protect.

---

## 4. Naming things in a shared workspace

Wanting a tab to say "Dotfiles" instead of "3" led somewhere more
interesting than expected.

**What the source says (herdr v0.8.0):** `tab_display_name` returns
`custom_name` or the tab number. That is the entire naming system. And
`TabRenameParams` is `{tab_id, label}` — no source, no TTL, no force.
The handler is one line.

So **`tab rename` is an unarbitrated global string setter**.
Last-writer-wins is the API's design, not a misuse of it. With several
agent sessions alive in one pane — herdr has no model for that; a pane
has at most one detected agent — they all rename the same tab and the
last one wins.

Two lessons fell out:

**Don't infer provenance from shape.** The first attempt at "was this
name set by a machine?" tested for a `/` (the `project/branch` shape).
It failed twice: sessions on `main`/`master`/`trunk` produce *no* slash,
and a human typing `notes/todo` gets clobbered. The working rule —
independently arrived at by three ecosystem plugins and a reviewer —
is **record what you wrote**. Overwrite only your own recorded value or
the tool's default. A human's name leaves no record and survives.

**Use the channel designed for it.** herdr *does* have an official
extension point for agent identity: `pane.report_metadata`'s
`display_agent`, keyed by `--source`, stored per source with a TTL. Two
sessions in one pane each get their own slot — the collision is
structurally impossible there. It was the tab name, a single shared
slot, that could not be shared.

---

## 5. The failure modes worth writing down

**Verify against the binary, not the source.** A design was reviewed
against a shallow clone of the project's default branch — unreleased
code. Every citation was accurate and none of it described the version
actually installed. Fetching the release tag settled it in one command.

**A check that passes without looking is worse than no check.** Three
instances in one codebase:

- `gitleaks` outside a repo: "0 commits scanned… no leaks found"
- CI's "full history" secret scan on a shallow checkout: one commit,
  same reassuring output
- A SHA-pinned scanning action that then ran `docker run …:latest`

Each reported success. The fix is the same every time: assert the check
*bit* something. Pin the count, feed it a canary, or measure what it
covered.

**Time-dependent tests are the same disease.** A test asserting "no API
call happens" broke when a legitimate cached read was added — passing or
failing depending on how recently the suite had last run. Two failures,
then a pass, with no code change in between. Fix: assert the property
that matters (no *write*), and force timing state deterministically
rather than relying on elapsed wall-clock.

**One working tree, many agents.** Several agents sharing one `yadm`
home directory is genuinely hazardous, and the dangerous commands are
the ones that leave *no reflog entry*: `restore`, `reset`, `checkout --
.`, `clean`. Branch operations are the visible, recoverable ones.
Staged work survived a wipe as unreachable objects and came back via
`git fsck --unreachable` — **stage early** is the practical mitigation,
and it worked.

**Review is a lever, not an oracle.** Across ~15 review rounds the
reviewer caught four defects that would have shipped broken, including
the array-replace bug. It was also confidently wrong twice — once
recommending a fix that corrupted a live config, once measuring
idempotency against a fixture that by construction could not contain
the input that breaks it. Both were caught by *running* the
recommendation rather than accepting it. Its own summary of the pattern
is the best line to end on: **a reviewer's confidence is not evidence.**

---

## What shipped

| Tool | What it does |
| --- | --- |
| `claude-copy-last` (`ccl`) | Copies the Nth-latest reply as raw markdown |
| `claude-settings-sync` | Installs shared settings only |
| `hbox` | Remote attach with the keybinding flag baked in |
| `pre_pull` / `post_pull` | Snapshot before a pull, restore after |
| statusline switches | One script; segments set per machine |

All of it is ~600 lines of bash and `jq`, with 141 tests. The tests are
the interesting part: most of them exist because something failed
silently once.
