# herdr（試驗中）

[herdr](https://herdr.dev/) 是感知 AI agent 狀態的多工器，目前進行
兩週試驗——只承載 Claude Code session，tmux 仍是主力。自
2026-08-05 起由 herdr **自家 updater** 管理（**非** Homebrew——
上游對 brew 安裝停用 `herdr update`，且只有自家 updater 支援
live handoff）：升級用 `herdr update --handoff`，替換本機 server
時 pane 不死。協定在版本不匹配時拒絕 attach；`--remote` attach
會自動同步遠端 binary（詳見 [herdr-setup.md](herdr-setup.md)，
英文）。設定在
`~/.config/herdr/config.toml`（ctrl+a prefix、對映 tmux 鍵位、
Catppuccin）。插件屬機器本地產物；新機器以 SHA 釘版安裝
（皆為小型第三方 repo，`--ref` 是供應鏈防護）：

```bash
herdr plugin install --yes paulbkim-dev/vim-herdr-navigation \
  --ref 820d48f5d9c9a7dece6a4bebfa3982ec30bbfbb7
herdr plugin install --yes andrewchng/herdr-sessionizer \
  --ref 20827358a8da57b83d479cf899909bbf11919541
herdr plugin install --yes iurysza/termscope \
  --ref cbc6da8103c263343b7082e27e804cc91312f944   # build 可能經 brew 升級 television
herdr plugin install --yes NathanFlurry/herdr-plugin-jj-workspace \
  --ref a9f1d3bcdaa2354e336a5173da85cbe4970c0f2e
herdr plugin install --yes persiyanov/herdr-reviewr \
  --ref 42ccaaa72176937181c82a91484f97466fb5ed59 # 審閱 agent diff，prefix+e
herdr plugin install --yes iurysza/herdr-tab-smart-rename \
  --ref a580a9ef248357ea9d85cf0f2131acb2e3fae240 # 依主題自動命名分頁
herdr integration install claude   # 重新生成 agent-state hook
```

相對 tmux 組合的已知限制：sessionizer 沒有 blacklist、picker 預覽
寫死（`bat`/`ls`，非 eza）；jj 插件的 *remove* 是銷毀性操作
（forget + `rm -rf`，故意不綁鍵）。

完整雙機建置指南（工作筆電／遠端 Linux、remote attach、通知、
升級紀律）：[herdr-setup.md](herdr-setup.md)（英文）
