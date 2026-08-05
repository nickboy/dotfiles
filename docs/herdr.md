# herdr (trial)

[herdr](https://herdr.dev/) is an AI-agent-aware multiplexer under a
two-week trial for Claude Code sessions only — tmux stays primary.
Managed by herdr's OWN updater since 2026-08-05 (NOT Homebrew —
upstream disables `herdr update` for brew installs, and only the
self-updater supports live handoff): upgrade with
`herdr update --handoff`, which replaces the local server without
killing panes. Its wire protocol refuses attach across versions;
`--remote` attaches auto-sync the remote binary (see
[herdr-setup.md](herdr-setup.md)).
Config: `~/.config/herdr/config.toml` (ctrl+a
prefix, tmux-mirrored keys, Catppuccin). Plugins are machine-local;
on a new machine install them SHA-pinned (small third-party repos —
the `--ref` pin is the supply-chain guard):

```bash
herdr plugin install --yes paulbkim-dev/vim-herdr-navigation \
  --ref 820d48f5d9c9a7dece6a4bebfa3982ec30bbfbb7
herdr plugin install --yes andrewchng/herdr-sessionizer \
  --ref 20827358a8da57b83d479cf899909bbf11919541
herdr plugin install --yes iurysza/termscope \
  --ref cbc6da8103c263343b7082e27e804cc91312f944   # build may brew-bump tv
herdr plugin install --yes NathanFlurry/herdr-plugin-jj-workspace \
  --ref a9f1d3bcdaa2354e336a5173da85cbe4970c0f2e
herdr plugin install --yes persiyanov/herdr-reviewr \
  --ref 42ccaaa72176937181c82a91484f97466fb5ed59 # review agent diffs, prefix+e
herdr plugin install --yes iurysza/herdr-tab-smart-rename \
  --ref a580a9ef248357ea9d85cf0f2131acb2e3fae240 # auto-names tabs by topic
herdr integration install claude   # regenerates the agent-state hook
```

Known limits vs the tmux stack: sessionizer has no blacklist and its
picker preview is hard-coded (`bat`/`ls`, not eza); the jj plugin's
*remove* action is destructive (forget + `rm -rf`, left unbound).

Full dual-machine setup (work laptop / remote Linux server, remote
attach, notifications, upgrade discipline):
[herdr-setup.md](herdr-setup.md)
