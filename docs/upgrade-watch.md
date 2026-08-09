# Upgrade Watch

Running latest versions everywhere means a handful of tracked config
files are bound to an upstream schema that has already changed under
them, so each one below has a canary — a command that fails loudly when
the config stops parsing — run by both the test suite and daily
maintenance.

| Config file | Upstream | Breakage history | Canary |
| --- | --- | --- | --- |
| `~/.config/yazi/yazi.toml` | Yazi | (1) | `yazi --version` |
| `~/.config/atuin/config.toml` | Atuin | (2) | `atuin doctor` |
| `~/.tmux.conf` | tmux | (3) | throwaway-server parse |
| `~/.config/herdr/config.toml##template` | herdr | (4) | suite TOML lint |
| `~/.config/zellij/*` | Zellij | (5) | `zellij setup --check` |
| `lazygit config.yml` | lazygit | (6) | none needed |
| `~/.local/bin/env` (uv artifact) | uv | (7) | suite `env` check |
| bob data dir (PATH + maintenance) | bob (git dev) | (8) | suite nvim boot |
| `~/.claude/projects/*.jsonl` | Claude Code | (9) | suite fixture test |

## Notes

1. **Yazi** — 26.x renamed the fetcher key `id` to `group`. A parse
   failure is silent: yazi falls back to its preset config, which cost
   weeks before anyone noticed. The next release changes `theme.toml`
   `[help]` keys (`on` → `chord`, `run`/`desc` → `action`, `footer`
   removed); our `theme.toml` has no `[help]` section today.
2. **Atuin** — 18.19 removed the skim search engine, so
   `search_mode = "skim"` is now dead config (we use the default fuzzy
   engine). Daemon mode is enabled here and needs
   `brew services start atuin` per machine; the suite asserts the socket
   is live whenever the config enables it.
3. **tmux** — 3.8 (not in Homebrew yet) adds a native light/dark theme
   system that may fight the catppuccin plugin: on upgrade set
   `set -g theme terminal` first to keep current behaviour. It also adds
   floating panes (a candidate to replace `display-popup`) and OSC 133
   command hooks.
4. **herdr** — the wire protocol refuses to attach across ANY version
   gap. `herdr integration install claude` rewrites `settings.json` with
   an absolute `/Users` path; re-fix it to `$HOME` afterwards.
   Self-updater managed since 2026-08-05 (left the Brewfile — brew
   installs can't live-handoff): upgrade via `herdr update --handoff`;
   never from non-interactive automation.
5. **Zellij** — 0.44 swapped wasmtime for wasmi, breaking every wasm
   plugin built before 2026-03. zjstatus needs ≥ 0.23; the layout pins
   v0.24.0 by URL.
6. **lazygit** — 0.64 moved the commit confirm from `alt+enter` to
   `cmd+enter` on Mac. Muscle memory only: we define no custom
   keybinds, so there is nothing to change.
7. **uv** — `~/.local/bin/env` is a PATH snippet meant to be sourced. If
   it ever becomes executable it shadows `/usr/bin/env` and swallows
   commands; the suite asserts `env` still resolves to `/usr/bin/env`.
8. **bob** — the git-dev build moved its data dir to
   `~/Library/Application Support/bob` (July 2026), abandoning
   `~/.local/share/bob`. A half-finished install there wedged nightly
   updates for a month ("Couldn't find bob.json") while plugins kept
   advancing — until neo-tree called an API the frozen nvim lacked.
   PATH and the maintenance proxy-chmod now target the new dir (old
   kept as fallback). The suite's headless nvim boot is the canary.
9. **Claude Code transcripts** — `claude-copy-last` (alias `ccl`,
   tmux `prefix+O`) reads the session transcript JSONL under
   `~/.claude/projects/<slug>/`, filtering on `.type == "assistant"`
   and `.isSidechain`, then pulling `.message.content[].type` and
   `.text`. That is Claude Code's internal on-disk format with no
   compatibility guarantee: a renamed field anywhere in it turns a
   copy into silent nothing. The suite's fixture test
   ("claude-copy-last extracts latest message from fixture") is the
   canary — it fails the day the schema drifts.
   The herdr delivery path (`-c` from `prefix+shift+o`) additionally
   pins three herdr internals (all verified 0.8.0, watched by the
   suite's stub-herdr OSC 52 tests): custom commands are stripped
   from client keymaps (`parse_client_keybindings` —
   `--remote-keybindings=server` is load-bearing), clipboard writes
   over 192 KiB decoded are silently dropped (`MAX_CLIPBOARD_BYTES`,
   script guards at 190 KiB), and `pane process-info` omits `tty` on
   macOS so the script falls back to `/bin/ps -o tty=`. If an
   upgrade changes any of these, the keybinding goes dark or the
   toast fallback stops firing.
   **Open follow-ups on the herdr tab/identity work** (2026-08-08, all
   deliberately deferred, none urgent):
   - *Verify the tab, don't trust it.* `HERDR_TAB_ID` is injected at
     pane spawn and is never updated, so it is wrong after `pane move`
     and is inherited by anything launched from that pane. Two sessions
     that both think they own a tab still alternate once a minute.
     Buildable on 0.8.0: intersect this process's parent chain with each
     pane's `shell_pid` + foreground pids from `pane process-info` —
     exactly one pane matches. Cache per session, not per tick.
   - *Upstream FR:* `tab.rename` takes `{tab_id, label}` with no source
     field, so programmatic renames are indistinguishable from typed
     ones and cannot be arbitrated. Every tab-rename plugin in the
     ecosystem reinvents the same state file, and so do we. Ask for a
     `source` on `tab.rename`, matching `pane.report_metadata`.
     Second FR: for an unnamed tab, `label` (positional, `tab_idx + 1`)
     and `number` (monotonic) in the SAME response disagree after any
     tab close.
   - *herdr installer idempotency* (owned by the HerdDeck session): it
     matches its existing install on the full command string, so the
     `$HOME` rewrite this repo prescribes reads as absent and it appends
     a duplicate.

   It also reads `herdr pane get <id>` →
   `.result.pane.agent_session.value` to select the transcript
   belonging to the pane you pressed in. Renaming that field only
   degrades to the old newest-file guess, which is wrong whenever two
   agents share a directory — silently pasting the other pane's
   reply. The suite asserts session-id selection beats mtime.
