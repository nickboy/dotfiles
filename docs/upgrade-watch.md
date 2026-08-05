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
