# herdr（試驗中）

[herdr](https://herdr.dev/) 是感知 AI agent 狀態的多工器，目前進行
兩週試驗——只承載 Claude Code session，tmux 仍是主力。formula
刻意**不釘版**——每日維護會跟上每個 release。其協定在版本不匹配時
拒絕 attach，因此維護腳本偵測到「升級落在活著的 server 上」時會發
桌面通知而非殺掉它：方便時再重啟（`herdr server stop` 後 `herdr`，
agent pane 會原生 resume）。設定在
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
herdr integration install claude   # 重新生成 agent-state hook
```

相對 tmux 組合的已知限制：sessionizer 沒有 blacklist、picker 預覽
寫死（`bat`/`ls`，非 eza）；jj 插件的 *remove* 是銷毀性操作
（forget + `rm -rf`，故意不綁鍵）。

完整雙機建置指南（工作筆電／遠端 Linux、remote attach、通知、
升級紀律）：[herdr-setup.md](herdr-setup.md)（英文）
