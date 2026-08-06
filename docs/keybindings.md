# Keybindings

This page is generated from the dotfiles config files below. It lists
every user-facing shortcut, layered by which app owns the keystroke.

- `~/.config/ghostty/config`
- `~/.tmux.conf`
- `~/.config/herdr/config.toml##template`
- `~/.config/yazi/keymap.toml`
- `~/.config/kitty/kitty.conf`

## Layer 1: Ghostty (cmd / cmd+alt)

Terminal emulator. Bindings come from the `keybind =` lines.

| Key | Action |
| --- | --- |
| `shift+enter` | Insert newline in shell |
| `cmd+k` | Clear screen |
| `cmd+shift+,` | Reload config |
| `cmd+up` | Jump to previous shell prompt |
| `cmd+down` | Jump to next shell prompt |
| `cmd+shift+enter` | Toggle split zoom |
| `cmd+alt+h` | Focus split left |
| `cmd+alt+j` | Focus split down |
| `cmd+alt+k` | Focus split up |
| `cmd+alt+l` | Focus split right |
| `global:cmd+grave_accent` | Toggle Quick Terminal dropdown |

`cmd+d` / `cmd+shift+d` are unbound on purpose, so tmux handles splits.

## Layer 2: Multiplexers (ctrl+a prefix)

This table is the contract between the two multiplexers: any keybind
change on either side must update the matching row here, or record it
as an intentional divergence. `prefix+ctrl+a` (`C-a C-a`) sends a
literal prefix keystroke through to the app in both tools — the
escape hatch for nested or remote tmux sessions.

tmux and herdr share the `ctrl+a` prefix. One table, two action
columns, so shared muscle memory and divergences both stand out.
`—` means the tool has no binding at that key in the config file.

| Key | tmux action | herdr action |
| --- | --- | --- |
| `prefix+ctrl+a` | Send literal ctrl+a to app | Same, built-in |
| `prefix+r` | Reload config (legacy alias) | Enter resize mode (default) |
| `prefix+\` | New pane right | New pane right (split_vertical) |
| `prefix+-` | New pane below | New pane below (default) |
| `prefix+c` | New window | — |
| `prefix+h/j/k/l` | Focus pane L/D/U/R | Focus pane L/D/U/R (default) |
| `prefix+H/J/K/L` | Resize pane by 5 (repeatable) | — |
| `prefix+<` | Swap window with previous | — |
| `prefix+>` | Swap window with next | — |
| `prefix+alt+g` | Open lazygit popup | Open lazygit popup |
| `prefix+e` | Lazygit popup (review) | Reviewr: review agent diffs |
| `prefix+t` | Scratch terminal popup | Scratch terminal popup |
| `prefix+T` | sesh session picker (fzf) | — |
| `prefix+F` | Highlight links/paths to copy | — |
| `prefix+?` | Which-key popup (list shortcuts) | Show help (default) |
| `prefix+R` | Reload config | Reload config (default) |
| `prefix+g` | — | Go to / jump |
| `prefix+w` | — | Workspace picker |
| `prefix+shift+n` | — | New workspace |
| `prefix+shift+g` | — | New worktree (per agent) |
| `prefix+f` | Open project picker | Open project picker |
| `prefix+shift+f` | — | Open worktree workspace |
| `prefix+u` | — | Open visible link picker |
| `prefix+shift+u` | — | Open visible file picker |
| `prefix+shift+j` | — | New jj workspace |
| `prefix+alt+j` | — | New jj workspace (new tab) |
| `prefix+1..9` | Switch to window N (default) | Switch to tab N (default) |
| `prefix+[` | Copy mode, vi keys | Copy mode, vi keys (default) |
| `prefix+P` | Copy previous command's output | — (FR drafted) |
| `prefix+O` | Copy Claude's last reply (transcript) | — (FR drafted) |
| `F12` | Toggle nested/outer tmux | — |

Copy mode is the same in both tools: `prefix+[` to enter, then vim
motions (`h/j/k/l`, `w/b/e`, `0/^/$`, `{`/`}`, `g/G`), `/`+`n/N` to
search, `v` to start a selection (`V` whole line), `y` to copy and
exit, `q` to leave without copying. tmux additionally has `C-v` for
rectangle selection and `(` / `)` to jump backward / forward between
shell prompt marks. For structured strings (paths, URLs, hashes)
skip copy mode entirely: `prefix+F` (tmux thumbs) or `prefix+u`/
`prefix+shift+u` (herdr termscope) hint-pick them in one keystroke,
and Ghostty's `cmd+f` searches the scrollback directly.

Copying a whole block comes in two flavours. `prefix+P` grabs the
previous command's complete output by walking the OSC 133 prompt
marks that Ghostty's zsh shell integration emits (they survive into
tmux panes), so it covers shell commands only. Claude Code's TUI
emits no OSC 133 marks at all, which is why `prefix+O` — and the
`ccl` alias for `~/.local/bin/claude-copy-last` — skips the screen
entirely and reads the session transcript JSONL instead, returning
the original markdown rather than the rendered, wrapped text.

Notes on divergences:

- `prefix+T` (sesh) has no herdr key match; closest is `prefix+f`.
- `prefix+r` (lowercase) is tmux's legacy reload alias; herdr enters
  resize mode instead — an intentional divergence, not an alignment.
- `prefix+R` (uppercase) is the aligned reload key in both tools.
- `prefix+P` / `prefix+O` have no herdr equivalent yet; both are
  drafted as upstream feature requests.
- jj workspace removal is unbound on purpose (destructive action).

## Layer 3: Seamless navigation (bare ctrl+h/j/k/l)

Bare `ctrl+h/j/k/l` (no prefix) crosses vim, tmux, and herdr splits
in one motion: vim-tmux-navigator inside tmux, vim-herdr-navigation
inside herdr.

| Key | Action |
| --- | --- |
| `ctrl+h` | Focus left (vim-tmux-navigator / vim-herdr-navigation) |
| `ctrl+j` | Focus down (vim-tmux-navigator / vim-herdr-navigation) |
| `ctrl+k` | Focus up (vim-tmux-navigator / vim-herdr-navigation) |
| `ctrl+l` | Focus right (vim-tmux-navigator / vim-herdr-navigation) |

## Layer 4: Yazi file manager

Bindings come from `prepend_keymap` under `[mgr]`.

| Key | Action |
| --- | --- |
| `gd` | Go to Downloads |
| `gp` | Go to Projects |
| `gc` | Go to ~/.config |
| `gD` | Go to Desktop |
| `gt` | Open Ghostty here |
| `<Enter>` | Enter dir or open file (smart-enter) |
| `f` | Jump to char (jump-to-char) |
| `F` | Smart filter |
| `T` | Toggle max preview |
| `<C-t>` | Toggle hide preview |
| `cm` | Chmod selected files |
| `gg` | Open lazygit |
| `ca` | Compress selected files |
| `<C-d>` | Diff selected with hovered |
| `p` | Paste into hovered dir or CWD |
| `ba` | Tag selected files (macOS Finder) |
| `br` | Untag selected files (macOS Finder) |

Built-in, not in this file: `z` is a zoxide jump, `Z` is an fzf jump.

## Layer 5: Kitty (backup terminal)

Backup terminal, kept in sync with Ghostty where practical.
Bindings come from the `map` lines.

| Key | Action |
| --- | --- |
| `cmd+k` | Clear terminal to cursor |
| `cmd+shift+,` | Reload config |
| `shift+enter` | Insert newline |
| `cmd+shift+d` | New vertical split |
| `cmd+d` | New horizontal split |
| `cmd+left/right/up/down` | Focus neighboring window |
| `cmd+alt+h/j/k/l` | Focus neighboring window (vim-style) |
| `cmd+t` | New tab (current dir) |
| `cmd+w` | Close tab |
| `cmd+1..9` | Go to tab N |
| `cmd+plus` | Increase font size |
| `cmd+minus` | Decrease font size |
| `cmd+0` | Reset font size |
| `ctrl+shift+l` | Next window layout |
| `ctrl+shift+i` | Display image (icat) |
| `ctrl+shift+e` | Hints: select text/URL |
| `ctrl+shift+p>f/l/w/h` | Hints: select path/line/word/hash |
| `ctrl+shift+u` | Insert unicode character |
| `ctrl+shift+d` | Open diff kitten |
| `ctrl+shift+b` | Broadcast keys to all windows |
| `ctrl+shift+t` | Preview/switch theme |
| `ctrl+shift+f` | Choose fonts |
| `ctrl+shift+h` | Open scrollback in nvim |
