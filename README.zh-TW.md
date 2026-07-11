# Nick 的 Dotfiles

[![Dotfiles CI](https://github.com/nickboy/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/nickboy/dotfiles/actions/workflows/ci.yml)

> **語言**: [English](README.md) | 繁體中文

使用 [yadm](https://yadm.io/) 管理的個人 dotfiles，包含 macOS 開發環境的完整設定。

## 包含內容

### 核心設定

- **Shell**: Zsh 搭配 zinit 外掛管理器與 Oh-My-Zsh 外掛
- **編輯器**: Neovim (LazyVim) 與 Zed 設定
- **終端機**: Ghostty 與 Kitty 設定（Catppuccin Mocha 主題）
- **多工器**: tmux（搭配 sesh、which-key）與 Zellij（0.44+）
- **套件管理**: 透過 Brewfile 管理 Homebrew 套件
- **Git**: 全域 git 設定
- **現代 CLI 工具**: ripgrep、bat、eza、dust、duf、btop、yazi、
  lazygit 等（支援主題的工具皆使用 Catppuccin Mocha）
- **版本管理**: mise（多語言開發工具版本管理器）
- **自動補全**: Carapace（通用指令自動補全）
- **SSH**: 模組化 `config.d/` 架構，支援連線多工、keepalive 與
  強化安全預設（全域關閉 agent forwarding，信任主機逐一開啟）
- **Claude Code**: 豐富單行狀態列（成本、燒錢速率、session 時長、
  model、effort level、資料夾、git branch、rate limit、context 進度條）、
  Catppuccin Mocha 自訂主題、透過 OSC 9/777 桌面通知（支援 Ghostty、
  Neovim 及 SSH 遠端），claudecode.nvim 搭配 40% 分割寬度與 diff-in-new-tab
  工作流程
- **Neovim UI 增強**: treesitter-context（固定函式標頭）、
  illuminate（高亮游標下符號）、inc-rename（即時重新命名預覽）、
  自訂 ASCII 啟動畫面與平滑捲動動畫

### 自動化腳本

- **每日維護**: 自動更新 Homebrew、zinit、bob、LazyVim 並清理系統
  - 筆電關機時會在下次開機自動補執行
  - 快速存取別名：`mr`（執行）、`ms`（狀態）、`ml`（日誌）
- **電池監控**: 電池狀態監控工具

## 快速開始

### 前置需求

- macOS（已在 macOS 14+ 測試）
- 已安裝 [Homebrew](https://brew.sh/)
- 已安裝 [yadm](https://yadm.io/)：`brew install yadm`

### 安裝

1. **複製 dotfiles 倉庫：**

```bash
yadm clone https://github.com/nickboy/dotfiles.git
```

Bootstrap 腳本會在複製後自動執行：

- 設定設定檔 symlink（例如 Ghostty）
- 安裝 Homebrew（若尚未安裝）
- 從 Brewfile 安裝套件
- 設定 tmux 與 zinit 外掛管理器
- 設定每日維護自動化

1. **安裝剩餘的 Homebrew 套件（若 bootstrap 未完成）：**

```bash
brew bundle --file=~/Brewfile
```

1. **設定每日維護自動化（選用）：**

```bash
# 執行安裝腳本
bash ~/install-daily-maintenance.sh

# 或手動控制：
~/daily-maintenance-control.sh status
```

## 每日維護自動化

### 概覽

自動化每日系統維護任務，包括：

- Homebrew formula 更新（`brew upgrade`）
- Homebrew cask 更新 — `brew upgrade --cask --greedy-latest --yes`:
  非互動式,並涵蓋無版本號的 cask
- Zinit 外掛更新（`zinit update --all --quiet`）
- Oh-My-Zsh 更新
- Bob 自我更新：從 git dev 分支重建（SHA 快取，僅在上游推進時才重新
  編譯）
- Bob（Neovim 版本管理器）nightly 更新與舊版目錄清理
  （`bob install nightly` + `bob use nightly`）
- LazyVim 外掛更新（`nvim --headless '+Lazy! sync' +qa`）
- Treesitter parser 更新（`nvim --headless '+TSUpdate' +qa`）
- Homebrew 清理（`brew cleanup --prune=all`）— 移除舊版本並清除快取

### 功能特色

- 每日上午 9:00 透過 launchd 自動執行
- **補執行機制**：若錯過排程時間，登入時自動執行
- **並發鎖**：登入補執行不會與 9AM 排程互撞；殭屍鎖
  （PID 已死或超過 6 小時）會自動清除
- 完整日誌記錄至 `~/Library/Logs/`，超過 5 MB 自動輪替
- 網路步驟均在 watchdog timeout 下執行（timeout 中止與
  一般失敗在日誌中可區分）
- 錯誤處理與狀態報告
- 支援手動執行與便捷別名
- 簡易啟用/停用控制
- GitHub Actions CI/CD 流程
- Pre-commit hook 驗證
- 內建本機測試套件
- 無硬編碼路徑 — 使用 yadm 原生 `##template`（每次 clone/pull
  時由 `yadm alt` 自動重生）

### 安裝每日維護

#### 自動安裝

```bash
# 執行安裝腳本
bash ~/install-daily-maintenance.sh
```

#### 手動安裝

```bash
# 1. 設定腳本執行權限
chmod +x ~/daily-maintenance.sh
chmod +x ~/daily-maintenance-control.sh

# 2. 從 yadm 範本產生 plist（clone/pull 時 yadm alt 也會
#    自動執行，通常已經完成）
yadm alt

# 3. 載入 LaunchAgent（現代 launchctl，回傳真實 exit code）
launchctl enable "gui/$(id -u)/com.daily-maintenance"
launchctl bootstrap "gui/$(id -u)" \
  ~/Library/LaunchAgents/com.daily-maintenance.plist
```

### 使用方式

#### 快速存取別名（在 .zshrc 中設定）

```bash
# 日常操作快捷鍵
mr  # 手動執行維護（跳過日期檢查）
ms  # 檢查維護狀態
ml  # 查看維護日誌
```

#### 完整控制指令

```bash
# 檢查狀態
~/daily-maintenance-control.sh status

# 手動執行
~/daily-maintenance-control.sh run

# 查看日誌
~/daily-maintenance-control.sh logs

# 停止自動化
~/daily-maintenance-control.sh stop

# 啟動自動化
~/daily-maintenance-control.sh start

# 編輯維護腳本
~/daily-maintenance-control.sh edit
```

### 設定

#### 變更排程

編輯 `~/Library/LaunchAgents/com.daily-maintenance.plist`：

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>9</integer>  <!-- 變更小時 (0-23) -->
    <key>Minute</key>
    <integer>0</integer>   <!-- 變更分鐘 (0-59) -->
</dict>
```

編輯後重新載入：

```bash
~/daily-maintenance-control.sh restart
```

#### 新增指令

編輯 `~/daily-maintenance.sh`，依照現有模式新增指令：

```bash
if ! run_command "描述" your-command --args; then
    FAILED_COMMANDS+=("your-command")
fi
```

### 疑難排解

#### 檢查自動化是否正在執行

```bash
launchctl list | grep daily-maintenance
```

#### 查看最新日誌

```bash
tail -f ~/Library/Logs/daily-maintenance.log
```

#### 查看錯誤日誌

```bash
tail -f ~/Library/Logs/daily-maintenance-error.log
```

#### 重設自動化

```bash
~/daily-maintenance-control.sh stop
~/daily-maintenance-control.sh start
```

### 解除安裝

完全移除自動化（保留腳本）：

```bash
bash ~/uninstall-daily-maintenance.sh
```

或手動移除：

```bash
# 停止並卸載自動化
launchctl bootout "gui/$(id -u)/com.daily-maintenance"

# 選擇性：移除日誌檔
rm ~/Library/Logs/daily-maintenance*.log
```

## Ghostty 終端機設定

### Ghostty 功能特色

- **透明度**: 背景透明度 (0.82) 搭配模糊半徑 15 的 macOS
  玻璃效果（針對文字對比度調校），`background-opacity-cells`
  讓 ANSI 背景色（如 diff 高亮）也跟著透明
- **廣色域**: `window-colorspace = display-p3` 讓 Catppuccin Mocha
  的紫藍色在 M 系列 Mac 上渲染更飽和
- **捲動緩衝區**: 25 MB scrollback buffer，容納 Claude Code
  的長輸出
- **Shell 整合**: 增強的 shell 整合，搭配 `sudo`、`title`、`path`
  功能（停用 `cursor` 以避免與自訂 GLSL 游標著色器衝突）
- **智慧剪貼簿**: 受保護的貼上功能（bracketed paste mode）
- **Option 作為 Alt**: 左 Option 鍵作為 Alt 使用，支援
  單字移動（`Alt+B/F/D`）
- **視窗狀態持久化**: 重新啟動時總是恢復視窗佈局
  （`window-save-state = always`）
- **儲存格微調**: `adjust-cell-width = 1%` 改善 Nerd Font
  圖示對齊，`adjust-cell-height = 2` 改善行距
- **提示導航**: `Cmd+Up/Down` 在捲動緩衝區中跳轉 shell
  提示
- **分割縮放**: `Cmd+Shift+Enter` 最大化/還原分割窗格
  （在窗格間導航時保留縮放狀態）
- **調整大小覆蓋層**: 調整視窗大小時顯示尺寸
- **連結預覽**: 懸停 URL 即可預覽
- **自動更新**: Ghostty 有新版本時發出通知
- **鈴聲通知**: Dock 彈跳與標籤頁鈴聲表情，適用於權限請求提醒
- **桌面通知**: 透過 `claude-notify` hook 的 OSC 9/777 橫幅通知
  （支援 Ghostty 直接執行、Neovim 終端機及 SSH 遠端工作階段）
- **指令完成通知**: 執行超過 5 秒的指令在非聚焦分割窗格中
  完成時，發出 macOS 橫幅通知（不只是鈴聲，透過
  `notify-on-command-finish`）
- **游標著色器**: 動畫游標效果（`cursor_slash.glsl`、
  `cursor_smear.glsl`）
- **設定重載**: `Cmd+Shift+,` 無需重啟即可重載設定
- **Quick Terminal**: `Cmd+`` 全域快捷鍵，Quake 風格下拉終端機
  （70% 高度，失去焦點自動收起）
- **非聚焦窗格變暗**: 非活躍分割窗格透明度降至 85%
- **視窗副標題**: 標籤列下方顯示目前工作目錄
- **滑鼠滾輪加速**: 2 倍滾輪速度，瀏覽更快
- **游標點擊移動**: `Option+Click` 在長指令中直接移動游標位置
- **純標籤列模式**: `macos-titlebar-style = tabs` 移除紅綠燈按鈕，
  保留標籤列
- **字型**: Maple Mono NF CN，含程式連字（`!=`→`≠`、
  `=>`→`⇒`）與 CJK 支援
- **主題**: Catppuccin Mocha

### Ghostty 快捷鍵

| 快捷鍵 | 動作 |
| --- | --- |
| `Cmd+`` | Quick Terminal（全域，任何 app 都能用） |
| `Cmd+Option+h/j/k/l` | vim 風格分割窗格導航 |
| `Cmd+Shift+Enter` | 切換分割窗格縮放 |
| `Cmd+Up/Down` | 跳至上一個/下一個提示 |
| `Cmd+K` | 清除畫面 |
| `Cmd+Shift+,` | 重載設定 |
| `Cmd+Click` | 在瀏覽器開啟 URL |
| `Option+Click` | 在指令列中移動游標 |

> **注意**：
>
> - 在 tmux 中且 `set -g mouse on` 時，需用 `Cmd+Shift+Click` 開啟 URL
>   （tmux 外使用 `Cmd+Click` 即可）。
> - Ghostty 原生分割（`Cmd+D` / `Cmd+Shift+D`）已刻意 unbind，改由
>   tmux 處理分割（`prefix + |` / `prefix + -`），避免
>   `vim-tmux-navigator` 無法跨越原生 pane 的問題。

### 主要設定

- 透明背景搭配模糊效果，呈現現代 macOS 風格
- 平衡內邊距搭配延伸儲存格背景色，呈現無縫外觀
- Shell 整合搭配 `sudo`、`title`、`path`（停用 `cursor` — 著色器
  處理游標渲染）
- 增強剪貼簿功能與貼上保護
- 滑鼠支援與焦點追隨滑鼠
- 啟用連結點擊與懸停預覽

注意：著色器位於 `~/.config/ghostty/shaders/`，透過
bootstrap 建立 symlink。修改後使用 `Cmd+Shift+,` 重載設定。

### Claude Code 通知（SSH 遠端）

在遠端 Linux 機器透過 SSH 執行 Claude Code 時，如需桌面通知，
請複製通知腳本與 hook 設定：

```bash
scp ~/.local/bin/claude-notify remote:~/.local/bin/
scp ~/.claude/settings.json remote:~/.claude/
```

OSC 9/777 跳脫序列會透過 SSH 傳回 Ghostty，由 Ghostty
顯示 macOS 橫幅通知。遠端機器不需要安裝額外工具（如
`terminal-notifier`）。請確認 Ghostty 已加入專注模式的允許
應用程式清單。

## SSH 設定

### 模組化架構

SSH 設定使用 `Include config.d/*` 將共用預設值與機器特定設定
分開。這讓同一份 dotfiles 可以在個人與工作筆電上使用而不衝突。

```text
~/.ssh/
├── config              # Include 指令 + 機器特定設定
├── config.d/
│   └── 00-defaults.conf  # 共用預設值（yadm 追蹤）
└── sockets/            # ControlMaster socket 目錄
```

### 共用預設值（`00-defaults.conf`）

- **連線多工**: `ControlMaster auto` 搭配 10 分鐘 socket
  持久化 — 第二次 SSH 到同一主機幾乎即時
- **Keepalive**: 每 30 秒發送，容忍 3 次遺漏（90 秒偵測）
- **Agent Forwarding**: 全域設定 `ForwardAgent no`（被入侵的
  伺服器可能盜用你的金鑰）— 信任主機以 `Host <name>` 區塊
  設定 `ForwardAgent yes` 逐一開啟
- **強化安全預設**: `IdentitiesOnly yes`、
  `StrictHostKeyChecking ask`、`HashKnownHosts no`
- **壓縮**: 所有連線啟用壓縮
- **TERM 處理**: `SetEnv TERM=xterm-256color` 解決遠端機器
  缺少 `xterm-ghostty` terminfo 的問題

### 工作筆電設定

在已有公司 SSH 設定的工作筆電上拉取這些 dotfiles 時：

1. **拉取前備份現有 SSH 設定**：

   ```bash
   cp ~/.ssh/config ~/.ssh/config.bak
   ```

2. **拉取 dotfiles**：

   ```bash
   yadm pull
   ```

3. **合併公司設定** — 加在 `~/.ssh/config` 的 `Include` 行
   下方：

   ```ssh-config
   # Load modular configs (YADM-managed defaults + any machine-specific overrides)
   Include config.d/*

   # 公司 SSH 設定（從備份檔案貼入）
   Host bastion.corp.example.com
       User corporate-username
       IdentityFile ~/.ssh/id_corporate
       ProxyJump none

   Host *.internal.corp.example.com
       User corporate-username
       ProxyJump bastion.corp.example.com
   ```

   或者將公司設定放在獨立檔案如
   `~/.ssh/config.d/10-work.conf`（如不想透過 yadm 分享，
   可加入 `.gitignore`）。

4. **建立必要目錄**（若不存在）：

   ```bash
   mkdir -p ~/.ssh/sockets ~/.ssh/config.d && chmod 700 ~/.ssh/sockets
   ```

**注意**：SSH 使用「第一個匹配勝出」規則 — 公司的特定
`Host` 設定永遠優先於 `00-defaults.conf` 中的 `Host *`
預設值。你的公司設定不會被覆蓋。

## Neovim Claude Code 整合

### claudecode.nvim 設定

LazyVim claudecode extra 的自訂設定
（`~/.config/nvim/lua/plugins/claudecode.lua`）：

| 設定 | 值 | 說明 |
| --- | --- | --- |
| `split_width_percentage` | `0.40` | 40% 寬度（預設 30%） |
| `git_repo_cwd` | `true` | 從 git repo 根目錄啟動 Claude |
| `show_native_term_exit_tip` | `false` | 不顯示退出提示 |
| `diff_opts.open_in_new_tab` | `true` | Diff 在新分頁開啟 |
| `diff_opts.keep_terminal_focus` | `true` | Diff 開啟後保持焦點在 Claude |
| `diff_opts.hide_terminal_in_new_tab` | `true` | 全螢幕 diff 檢視 |
| `focus_after_send` | `true` | 傳送選取後聚焦 Claude |

### Claude Code 快捷鍵

| 快捷鍵 | 模式 | 動作 |
| --- | --- | --- |
| `<leader>ac` | n | 切換 Claude 終端機 |
| `<leader>af` | n | 聚焦 Claude 終端機 |
| `<leader>ar` | n | 恢復 Claude（`--resume`） |
| `<leader>aC` | n | 繼續 Claude（`--continue`） |
| `<leader>ab` | n | 將目前緩衝區加入上下文 |
| `<leader>as` | v | 傳送視覺選取至 Claude |
| `<leader>aa` | n | 接受 diff |
| `<leader>ad` | n | 拒絕 diff |
| `<leader>am` | n | 選擇 Claude 模型（Opus/Sonnet/Haiku） |
| `<Esc><Esc>` | t | 退出終端機模式（捲動 Claude 輸出） |

### Neovim UI 增強快捷鍵

| 快捷鍵 | 動作 |
| --- | --- |
| `<leader>ut` | 切換 treesitter-context（固定函式標頭） |
| `<leader>ux` | 切換 illuminate（高亮游標下符號） |
| `<leader>cr` | inc-rename（透過 LSP 即時重新命名預覽） |
| `<leader>cs` | 切換符號大綱側邊欄 |
| `<leader>uB` | 切換行內 git blame（GitLens 風格） |
| `gD` | Glance：預覽定義 |
| `gR` | Glance：預覽參考 |
| `gY` | Glance：預覽型別定義 |
| `gM` | Glance：預覽實作 |

**自動功能**（無需快捷鍵）：

- **Dropbar**：VS Code 風格的麵包屑導航列，顯示於緩衝區頂部
- **彩虹縮排指引線**：每層縮排以不同顏色顯示（類似 VS Code Indent Rainbow）
- **Mini-indentscope**：目前作用域的動畫縮排指引線

### Diffview（Git Diff 檢視器）

並排 git diff 檢視器（`~/.config/nvim/lua/plugins/diffview.lua`）：

| 快捷鍵 | 動作 |
| --- | --- |
| `<leader>gd` | 開啟 diff 檢視（所有變更檔案） |
| `<leader>gf` | 目前檔案歷史 |
| `<leader>gF` | 完整分支/倉庫歷史 |
| `q` | 關閉 diff 檢視 |

### OSC52 剪貼簿（遠端工作階段）

Neovim 0.10+ 內建 OSC52 剪貼簿支援。設定檔
（`~/.config/nvim/lua/plugins/osc52.lua`）在偵測到
`SSH_CONNECTION` 或 `TMUX` 時自動啟用，無需額外工具即可
透過 SSH 將 yank 內容傳回本地剪貼簿。

完整剪貼簿鏈路：Neovim OSC52 → tmux passthrough（`all`）→
SSH → Ghostty（`clipboard-write = allow`）→ macOS 剪貼簿。

## Claude Code 客製化

### 豐富狀態列

`~/.local/bin/claude-statusline`（bash、shellcheck 乾淨）產出一條
緊湊單行，配色為 Catppuccin Mocha：

```text
🤖 Opus 4.7 | 🚀 xhigh | 💰 $14.12 | 🔥 $4/hr | ⏱ 3h32m |
  📁 ~ 🌿 ⚡branch | 5h: 41% | 7d: 64% ↻15h | ████░░░░░░ 44% ctx
```

各段落：

- **🤖 Model**（blue）— `model.display_name`
- **🚀 Effort level**（依等級變色）— 從 `settings.local.json` 的
  `.effortLevel` 讀，`xhigh` 顯示紅色
- **💰 Session 成本**（依門檻變色）— `.cost.total_cost_usd`
- **🔥 燒錢速率**— 成本 ÷ 時長即時算
- **⏱ 時長**（dim）— session wall clock
- **📁 資料夾**（lavender）— basename，home 顯示 `~`
- **🌿 Branch**（blue）— `git symbolic-ref`，yadm 後備（`⚡`
  前綴代表 yadm 管的 home）
- **5h / 7d**（依門檻綠 / 黃 / 紅）— rate limit 使用率，若有
  `resets_at` 會附倒數（`↻Hh:Mm`）
- **進度條**（70% 黃、90% 紅）— context window 使用百分比

效能：git branch 快取到 `/tmp/claude-statusline-git-<session_id>`，
TTL 5 秒；欄位擷取一次 `jq` 搞定。

### Catppuccin Mocha 主題

`~/.claude/themes/my-theme.json` 覆寫約 70 個 Claude Code 色彩 token
（text、邊框、diff、彩虹序列、rate-limit bar、subagent swatch 等），
讓 Claude Code 畫面與 Ghostty / tmux / fzf 的 Catppuccin 色盤一致。

每台機器各自啟用一次：

```text
/theme my-theme
```

選擇存在 `~/.claude.json`（runtime 狀態，不進 yadm）。主題定義檔跨機共用 —
pull 之後主題只是**可用**，不是**啟用**。

### 共享 vs 機器專屬設定

Claude Code 同時讀 `settings.json`（yadm 追蹤、共享）與
`settings.local.json`（gitignore、本機專屬）。拆分能讓敏感/個人設定
不會跑到共享 dotfiles repo：

- `~/.claude/settings.json` — model、Notification hook、啟用的 plugin、
  額外 marketplace
- `~/.claude/settings.local.json` — `statusLine`（指向
  `claude-statusline`）、`effortLevel`、權限 bypass flag、
  `permissions.defaultMode`

跟 `~/.gitconfig` vs `~/.config/git/config` 同樣思路：安全預設走 yadm，
會改變其他機器安全姿態的東西留本機。

### 尋找與恢復 Claude 工作階段

Claude Code 本身已內建跨專案的工作階段探索 — 關鍵在於替工作階段命名,
事後才認得出來。`SessionStart` hook(`~/.local/bin/claude-name-session`,
掛在 `settings.json`)會依專案與分支(`專案/分支`;SSH 時 `host:專案/分支`)
自動設定每個新工作階段的標題(效果等同 `/rename`),所以**不論用哪種方式
啟動**(終端、claudecode.nvim、ClaudeDeck、SSH)都會命名,並顯示在 prompt
列、`/resume` 選單、以及終端機/分頁標題。`.zshrc` 的 `claude()` 包裝函式
則額外把 tmux 視窗改名為 `🤖 <專案/分支>`(離開時恢復自動命名),讓執行中
的 Claude pane 在狀態列一眼可辨。

**本機探索:**

- `/resume` 開啟選單 — `Ctrl+A` 擴展到**所有專案**,`Ctrl+W` 到所有
  worktree,`Ctrl+B` 依分支過濾,`/` 依文字搜尋,貼上 PR URL 可找到
  建立該工作階段的 session。
- `claude --resume <名稱>` 依名稱恢復;`claude --continue` 恢復當前
  目錄最近的對話。
- `claude agents --all` 列出執行中、阻塞中、已完成的工作階段。
- `/rename` 替進行中的工作階段改名(接受 plan 時會自動命名)。

**遠端(SSH + tmux):**

- **用 detach,不要 exit。** 在遠端 tmux 視窗裡跑 `claude`,離開時按
  `Ctrl-a d` — Claude 會繼續執行。用 `ssht host` 重連即可回到原處
  (ControlMaster 讓重連幾乎瞬間;resurrect/continuum 撐過 tmux server
  重啟)。
- 包裝函式會把遠端視窗命名為 `🤖 host:專案`,讓巢狀 tmux 不混淆;
  按 **F12** 切換外層 tmux。
- 要找已退出的遠端工作階段,在遠端執行 `/resume` → `Ctrl+A`
  (它讀的是該主機的 `~/.claude/projects`)。
- `claude-notify`(OSC 9/777)與 OSC52 剪貼簿已把通知與複製橋接回
  Ghostty。

## 遠端開發

### Shell TERM 處理

Shell 會依環境自動設定 `TERM`：

- **本地（Ghostty）**: `xterm-ghostty` — 啟用 Ghostty 專屬
  功能（extended keyboard protocol、更好的渲染）
- **遠端（SSH）**: `xterm-256color` — 與所有伺服器相容

### 遠端工作輔助函式

在 SSH 工作階段中可用（定義在 `~/.zshrc`）：

```bash
# OSC52 剪貼簿 — 透過 SSH 複製到本地 macOS 剪貼簿
echo "text" | clip
clip "some text"

# pbcopy 別名 — 在遠端機器上透明運作
echo "text" | pbcopy

# 快速 SSH + tmux 附加或建立
ssht hostname              # 附加到 "main" 工作階段
ssht hostname mysession    # 附加到指定名稱的工作階段
```

### 巢狀 tmux 工作階段

透過 SSH 連線到同樣執行 tmux 的遠端機器時，本地與遠端
tmux 共用相同前綴（`Ctrl-a`）。按 **F12** 切換：

- **按一次 F12**: 停用外層 tmux（狀態列變灰），所有按鍵
  傳送到內層（遠端）tmux
- **再按一次 F12**: 重新啟用外層 tmux，恢復正常操作

## Kitty 終端機設定

### Kitty 功能特色

- **Monaspace 字型**: GitHub 的可變字型系列，搭配 Radon 斜體風格
- **合字**: 完整 OpenType 支援，包含 texture healing 與程式碼合字
- **游標軌跡**: 動畫游標軌跡效果（Kitty 0.37+ 專屬）
- **透明度**: 背景透明度 (0.75) 搭配模糊效果，與 Ghostty 一致
- **Kittens**: 內建圖片、提示、差異比較、主題等工具
- **遠端控制**: 透過 unix socket 進行腳本自動化
- **版面配置**: 7 種內建版面（tall、stack、fat、grid、splits 等）
- **主題**: Catppuccin Mocha（與 Ghostty 相同）

### Kitty 快捷鍵

| 快捷鍵 | 動作 |
| --- | --- |
| `Cmd+D` | 水平分割 |
| `Cmd+Shift+D` | 垂直分割 |
| `Ctrl+h/j/k/l` | Vim 風格窗格導航 |
| `Cmd+方向鍵` | 窗格導航 |
| `Ctrl+Shift+L` | 切換版面配置 |
| `Cmd+Shift+,` | 重載設定 |
| `Ctrl+Shift+I` | 顯示圖片 (icat) |
| `Ctrl+Shift+E` | 提示模式（URL、路徑） |
| `Ctrl+Shift+U` | Unicode 輸入 |
| `Ctrl+Shift+H` | 在 nvim 中開啟捲動緩衝區 |

### Kittens（內建工具）

- **icat**: 在終端機直接顯示圖片
- **hints**: 用鍵盤選取 URL、路徑、單字
- **diff**: 並排差異比較，支援語法高亮
- **themes**: 互動式預覽與切換主題
- **choose-fonts**: 預覽字型，支援可變字型
- **broadcast**: 同時在所有視窗輸入
- **unicode_input**: 依名稱插入 Unicode 字元

### 第三方整合

與支援圖片的工具無縫整合：

- **yazi/ranger**: 支援圖片預覽的檔案管理器
- **timg**: 圖片與影片檢視器
- **mpv**: 影片播放器（`mpv --vo=kitty video.mp4`）
- **awrit**: 基於 Chromium 的終端機瀏覽器
- **presenterm**: 支援圖片的 Markdown 簡報

## Zellij 設定

[Zellij](https://zellij.dev/) 是現代終端機多工器（tmux 的
替代方案），內建工作階段持久化、浮動/堆疊窗格與 WASM 外掛
生態系。設定針對 Zellij 0.44+。

### Zellij 功能特色

- **主題**: Catppuccin Mocha（與 Ghostty/tmux/Kitty 一致）
- **工作階段持久化**: 內建 session serialization，包含 viewport
  與 scrollback（取代 tmux-resurrect + tmux-continuum）
- **Vim 風格導航**: hjkl 快捷鍵處理窗格/分頁/調整大小/移動
- **Tmux 相容模式**: `Ctrl-b` 前綴模式，提供熟悉的 tmux
  快捷鍵（`"` 水平分割、`%` 垂直分割等）
- **滑鼠功能（0.44）**: 拖曳窗格邊框調整大小、`Ctrl+scroll`
  調整大小、`Alt+click` 以 `$EDITOR` 開啟檔案路徑
- **焦點追隨滑鼠**: 與 Ghostty 的 `focus-follows-mouse` 一致
- **無窗格外框**: 簡潔無邊框外觀（`Ctrl-p z` 切換）
- **版面管理器**: `Ctrl-o l` 儲存/套用/收藏版面
- **工作階段管理器**: `Ctrl-o w` 開啟內建工作階段切換器

### Zellij vs tmux vs Ghostty 分割

| 功能 | Ghostty 分割 | Zellij | tmux |
| --- | --- | --- | --- |
| 工作階段（detach/reattach） | 否 | 是 | 是 |
| SSH 斷線後存活 | 否 | 是 | 是 |
| 工作階段持久化 | 否 | 內建 | 外掛 |
| 浮動/堆疊窗格 | 否 | 是 | 否 |
| 外掛生態系 | 無 | WASM | Shell |
| 圖片預覽（yazi） | 是 | 否（無 passthrough） | 是 |

### Zellij 快捷鍵

| 快捷鍵 | 動作 |
| --- | --- |
| `Alt+h/j/k/l` | 窗格/分頁導航 |
| `Alt+n` | 新窗格 |
| `Alt+f` | 切換浮動窗格 |
| `Ctrl+p` | 窗格模式（接 h/j/k/l、n、d、r、x、z） |
| `Ctrl+t` | 分頁模式（接 n、r、x、1-9） |
| `Ctrl+n` | 調整大小模式（接 h/j/k/l） |
| `Ctrl+s` | 捲動模式（接 j/k、u/d，s 搜尋） |
| `Ctrl+o` | 工作階段模式（w=sessions、l=layouts、p=plugins） |
| `Ctrl+b` | Tmux 模式（熟悉的 tmux 快捷鍵） |
| `Ctrl+g` | 鎖定模式 |
| `Ctrl+q` | 離開 |

### Zellij Shell 別名

```bash
zj              # zellij
zja             # zellij attach
zjl             # zellij list-sessions
zjk             # zellij kill-session
zjd             # zellij delete-session
```

### 已知限制（0.44）

- **無圖片 passthrough**: Yazi 圖片預覽在 Zellij 中無法運作
  （尚未支援 Kitty graphics protocol 或 DCS passthrough）
- **第三方 WASM 外掛**: Zellij 0.44 將 runtime 從 wasmtime
  改為 wasmi；2026 年 3 月前編譯的外掛可能無法載入
  （例如 zjstatus v0.22.0）

### Zellij 設定檔

```text
~/.config/zellij/
├── config.kdl                    # 主設定（快捷鍵、各項設定）
├── themes/
│   └── catppuccin-mocha.kdl      # Catppuccin Mocha 主題
└── plugins/                      # WASM 外掛（已 gitignore）
```

## Tmux 設定

### 初始設定

TPM（Tmux Plugin Manager）由 bootstrap 腳本 git clone 至
`~/.tmux/plugins/tpm`（並非 Homebrew 套件）。安裝 dotfiles 後：

1. 啟動 tmux：`tmux new -s main`
2. 安裝外掛：按 `Ctrl-a + I`（大寫 I）
3. 外掛會自動安裝

### 設定功能

- **Truecolor + Ghostty RGB**: 終端機覆蓋設定支援完整
  24 位元色彩
- **透明度穿透**: Ghostty 背景透明度與模糊效果可穿透
  tmux 窗格顯示
- **OSC52 剪貼簿**: 透過 `set-clipboard on` 整合系統
  剪貼簿
- **DCS 穿透**: 完整穿透（`all`）啟用圖片協定、shell 整合與
  巢狀 OSC52 剪貼簿穿透 tmux
- **Undercurl 支援**: 為 Neovim LSP 診斷提供彩色波浪
  底線
- **視窗/窗格編號**: 從 1 開始（方便鍵盤操作）
- **滑鼠支援**: 啟用窗格選取與捲動
- **Vi 模式**: 複製模式使用 Vi 風格按鍵
- **自動重新編號**: 關閉視窗時自動重新編號
- **主題**: Catppuccin Mocha 搭配自訂狀態列
- **工作階段持久化**: 透過 tmux-resurrect/continuum
  自動儲存與復原
- **當前路徑分割**: 新分割與視窗會在目前工作目錄開啟
- **巢狀工作階段切換**: F12 停用外層 tmux，用於 SSH 遠端
  tmux 工作階段（狀態列變色提示）
- **tmux-yank**: 一致的複製行為，遠端工作階段自動使用 OSC52
- **tmux-thumbs**: 按 `prefix + F` 將畫面上的 URL / commit hash /
  檔案路徑覆蓋字母標示，輸入字母即複製到剪貼簿；大寫字母會
  複製後透過 `open` 開啟 URL
- **Claude Session Manager**: `Ctrl-a + y` 啟動/接上當前目錄的 Claude Code
  工作階段；`Ctrl-a + u` 開啟 live Claude session 的 fzf 選單，含
  working/waiting/idle 狀態與即時預覽（`craftzdog/tmux-claude-session-manager`
  ≥ v1.0.1；狀態直接讀自 `claude agents`——需 Claude Code ≥ 2.1.139 與
  `jq`，不再需要 Claude Code hooks）

### 按鍵綁定

#### 前綴鍵

- **前綴**: `Ctrl-a`（從預設 `Ctrl-b` 重新對應）

#### 視窗管理

| 快捷鍵 | 動作 |
| --- | --- |
| `Ctrl-a + 1-9` | 依編號切換視窗（從 1 開始） |
| `Ctrl-a + n` | 下一個視窗 |
| `Ctrl-a + p` | 上一個視窗 |
| `Ctrl-a + l` | 最近使用的視窗 |
| `Ctrl-a + w` | 從列表選擇視窗 |
| `Ctrl-a + c` | 建立新視窗 |
| `Ctrl-a + ,` | 重新命名目前視窗 |
| `Ctrl-a + &` | 關閉目前視窗 |
| `Ctrl-a + T` | 開啟 sesh 工作階段切換器（自訂） |

#### 窗格管理

| 快捷鍵 | 動作 |
| --- | --- |
| `Ctrl-a + \` | 水平分割（當前目錄） |
| `Ctrl-a + -` | 垂直分割（當前目錄） |
| `Ctrl-a + c` | 新視窗（當前目錄） |
| `Ctrl-a + h/j/k/l` | 在窗格間導航（vim 風格） |
| `Ctrl-a + H/J/K/L` | 調整窗格大小（可重複，5 格） |
| `Ctrl-a + <` | 向左交換視窗（可重複） |
| `Ctrl-a + >` | 向右交換視窗（可重複） |
| `Ctrl-a + x` | 關閉目前窗格 |
| `Ctrl-a + z` | 切換窗格縮放（最大化/復原） |
| `Ctrl-a + Space` | 切換窗格版面 |
| `Ctrl-a + {` | 向左移動窗格 |
| `Ctrl-a + }` | 向右移動窗格 |
| `Ctrl-a + r` | 重載 tmux 設定 |
| `Ctrl-a + F` | 高亮畫面上的 URL/hash/路徑（tmux-thumbs） |
| `Ctrl-a + y` | 啟動/接上當前目錄的 Claude session |
| `Ctrl-a + u` | Claude session 選單（狀態+即時預覽） |
| `F12` | 切換巢狀 tmux（用於 SSH 工作階段） |

#### 無縫導航

| 快捷鍵 | 動作 |
| --- | --- |
| `Ctrl-h/j/k/l` | 在 tmux 窗格與 vim 分割間無縫導航 |

#### 工作階段管理（sesh）

Sesh 是整合 zoxide 的智慧 tmux 工作階段管理器。
透過 `~/.config/sesh/sesh.toml` 設定了幾個專案模板：

- `dotfiles ~` — home 目錄，自動執行 `yadm status && nvim .`
- `claude config` — `~/.claude`
- `nvim config` — `~/.config/nvim`，開啟 `init.lua`
- `ghostty config` — `~/.config/ghostty`，開啟 `config`
- 以及 zoxide 訪問過的目錄（選取器的 `Ctrl-x` 模式）

**Shell 指令：**

| 指令 | 說明 |
| --- | --- |
| `s` | 互動式工作階段選取器（含 fzf 預覽） |
| `s myproject` | 連線至現有工作階段或從路徑建立 |
| `sn` | 以目前目錄名稱建立工作階段 |
| `sl` | 列出所有工作階段（含圖示） |
| `sls` | 僅列出 tmux 工作階段 |

**在 tmux 內：**

| 快捷鍵 | 動作 |
| --- | --- |
| `Ctrl-a + T` | 開啟進階 sesh 工作階段切換器 |

**工作階段切換器操作**（使用 `Ctrl-a + T` 時）：

- `Tab/Shift-Tab`: 瀏覽工作階段
- `Enter`: 連線至選取的工作階段
- `Ctrl-a`: 顯示所有工作階段
- `Ctrl-t`: 僅顯示 tmux 工作階段
- `Ctrl-g`: 顯示設定工作階段
- `Ctrl-x`: 顯示 zoxide 目錄
- `Ctrl-f`: 搜尋目錄
- `Ctrl-d`: 刪除選取的工作階段

**工作流程範例：**

```bash
# 開始一天的工作 — 選擇專案
s

# 在 tmux 內快速切換專案
Ctrl-a + T

# 新專案工作階段
cd ~/projects/my-app && sn

# 複製倉庫並建立工作階段
sesh clone https://github.com/user/repo
```

#### 複製模式

| 快捷鍵 | 動作 |
| --- | --- |
| `Ctrl-a + [` | 進入複製模式 |
| `v`（複製模式中） | 開始選取 |
| `y`（複製模式中） | 複製選取內容 |
| `q`（複製模式中） | 離開複製模式 |

## 現代 CLI 工具

以 Rust 為基礎的現代工具，取代傳統 Unix 工具：

| 傳統工具 | 現代工具 | 說明 | 別名 |
| --- | --- | --- | --- |
| `ls` | **eza** | 支援 git 狀態的現代 ls | `ls`, `ll`, `lt` |
| `cat` | **bat** | 支援語法高亮的 cat | `cat` |
| `grep` | **ripgrep** | 更快速的 grep | `rg` |
| `find` | **fd** | 更簡潔快速的 find | `fd` |
| `du` | **dust** | 直觀的磁碟使用量樹狀圖 | `du` |
| `df` | **duf** | 美觀的磁碟空間報告 | `df` |
| `top`/`htop` | **btop** | 精美的系統資源監控器 | `top`, `htop` |
| `dig` | **doggo** | 友善的 DNS 查詢工具 | `dog` |
| `sed` | **sd** | 更簡潔的搜尋取代 | `replace` |
| `ps` | **procs** | 現代程序檢視器 | `ps` |
| `cut` | **choose** | 友善的欄位選取 | `choose` |
| `time` | **hyperfine** | 指令效能測試工具 | `bench` |
| `hexdump` | **hexyl** | 彩色十六進位檢視器 | `hex` |
| `curl` | **xh** | 快速 HTTP 客戶端 | `http`, `https` |
| - | **tokei** | 程式碼統計工具 | `count` |
| `man` | **tlrc** | 快速指令範例 | `help`, `cheat` |
| - | **yazi** | 極速檔案管理器 | `y` |
| - | **serpl** | TUI 搜尋取代 | `sr` |
| - | **television** | 帶預覽的模糊搜尋器 | `tv` |
| - | **glow** | 終端機 Markdown 閱讀器 | `md` |
| - | **mods** | 將 shell 輸出管線送進 LLM（Charm） | `mods` |
| `git` | **jujutsu** | Git 相容版本控制系統 | `jj` |
| - | **jjui** | jujutsu 的 TUI | `jjui` |
| `nvm`/`pyenv` | **mise** | 多語言版本管理器 | `mise` |
| `make` | **just** | 指令執行器（簡潔的 justfile） | `just` |
| - | **tailspin** | 零設定 log 高亮/分頁器 | `tspin` |
| `tar`/`unzip` | **ouch** | 萬用壓縮/解壓縮 | `extract`, `x` |
| `diff` | **difftastic** | 語法樹層級的語義 diff | `git dft` |
| - | **mergiraf** | 語法感知合併衝突解決器 | (git driver) |
| - | **posting** | API 測試 TUI（請求存為 YAML） | `posting` |
| `thefuck` | **pay-respects** | 指令修正（Rust，cargo 安裝） | `fk` |

### Shell 增強功能

- **z-shell/zsh-eza**: 智慧 eza 別名，支援 git 狀態、圖示與分組
- **Atuin**: 增強 shell 歷史記錄，使用 SQLite 儲存、模糊搜尋與語法高亮
- **Oh-My-Zsh 函式庫**（透過 Zinit）：
  - `directories` — 目錄導航（`..`、`...`、`d`、1-9 堆疊、AUTO_CD）
  - `history` — 增強歷史記錄與時間戳（`HIST_STAMPS`）
  - `misc` — 實用函式（env、pgrep、confirm_wrapper）
- **Oh-My-Zsh 外掛**（透過 Zinit）：
  - `common-aliases` — 全域管道別名（H/T/G/L/NUL）
  - `colored-man-pages` — 語法高亮的 man 頁面
  - `web-search` — 從終端機搜尋（google、github、stackoverflow）
  - `sudo` — 按 ESC ESC 為上一個指令加上 sudo
  - `copypath` / `copyfile` — 快速剪貼簿操作
  - `jsontools` — JSON 格式化與驗證
  - `encode64` — Base64 編碼/解碼
- **壓縮檔解壓縮**: `extract` / `x` 別名執行 `ouch decompress`
  （取代 OMZ extract 外掛；多檔壓縮包會解進以壓縮檔命名的
  子目錄）
- **指令修正**: `fk` 執行 `pay-respects`（thefuck 的 Rust
  後繼者，由 bootstrap 腳本透過 cargo 安裝）

### 目錄導航

```bash
# 快速導航 (directories.zsh)
..              # cd ..
...             # cd ../..
....            # cd ../../..
d               # 顯示最近 10 個目錄（帶編號）
1               # 跳至第 1 個先前目錄
2               # 跳至第 2 個先前目錄（最多 9）
~/Projects      # 直接輸入路徑（已啟用 AUTO_CD）

# 智慧導航 (zoxide)
z project       # 跳至最常使用的 'project' 目錄
cd mydir        # 底層使用 zoxide
```

### 全域管道別名（common-aliases）

```bash
# 管道快捷鍵 — 附加在任何指令後
cat file.txt G "error"    # | grep "error"
cat file.txt H            # | head
cat file.txt T            # | tail
cat file.txt L            # | less
command NUL               # > /dev/null 2>&1
```

### 網頁搜尋

```bash
# 從終端機搜尋（web-search 外掛）
google "zsh tutorial"
github "zinit plugin"
stackoverflow "bash vs zsh"
ddg "privacy search"        # DuckDuckGo
youtube "vim tips"
```

### Shell 歷史記錄（Atuin）

Atuin 取代傳統 shell 歷史記錄，使用 SQLite 資料庫，提供語法高亮、
模糊搜尋與豐富的中繼資料。

功能：工作區感知篩選（上方向鍵顯示目前 git repo 範圍的歷史）、
vi 按鍵模式、緊湊風格、Catppuccin Mocha 主題、自動秘密篩選
（AWS 金鑰、GitHub PATs、Slack tokens、curl 認證標頭）、
git/docker/brew 子指令統計分組。

```bash
# 互動式歷史搜尋 (Ctrl+R)
# - 模糊搜尋搭配語法高亮
# - 篩選方式：主機、工作階段、目錄、工作區或全域
# - 再按 Ctrl+R 切換篩選模式
# - 上方向鍵依目前 git repo 篩選（工作區模式）

# 統計資料
atuin stats              # 顯示指令使用統計

# 搜尋指令
atuin search "git"       # 搜尋歷史中的 git 指令
atuin search --cwd .     # 僅搜尋目前目錄
```

**搜尋介面按鍵：**

| 按鍵 | 動作 |
| --- | --- |
| `Ctrl+R` | 開啟搜尋 / 切換篩選模式 |
| `↑/↓` | 瀏覽結果 |
| `Enter` | 執行選取的指令 |
| `Tab` | 插入指令以編輯 |
| `Esc` | 離開搜尋 |

### FZF Git 快捷工具

```bash
# 模糊分支切換（依最近提交排序）
gb

# 從 git log 模糊切換
gl

# Ripgrep + FZF 互動式程式碼搜尋（Enter 在 nvim 開啟）
rgf "pattern"
```

### 使用範例

```bash
# 現代檔案列表，含 git 狀態
ls              # eza 搭配圖示、git 狀態、目錄優先
ll              # 長格式搭配標頭
lt              # 網格檢視搭配詳細資訊
tree            # 樹狀檢視

# 磁碟分析
dust            # 視覺化磁碟使用量樹狀圖
duf             # 美觀的磁碟空間報告

# 系統監控
btop            # 精美的系統資源監控器

# DNS 查詢
dog google.com  # 彩色 DNS 查詢

# HTTP 請求
http GET https://api.example.com/users
xh POST https://api.example.com/data key=value

# 效能測試
bench 'command1' 'command2'  # 比較效能

# 程式碼統計
count .         # 依語言統計程式碼行數

# 快速說明
help tar        # 顯示 tar 範例
cheat docker    # Docker 指令範例

# 檔案管理 (yazi)
y               # 開啟 yazi，離開時 cd 至最後目錄
y ~/Downloads   # 在指定目錄開啟 yazi

# Markdown 閱讀
md README.md    # 在終端機渲染 Markdown

# 搜尋取代 (serpl)
sr              # 開啟 TUI 搜尋取代

# 帶預覽的模糊搜尋 (television)
tv              # 開啟 television 模糊搜尋器
```

### Yazi 檔案管理器

[Yazi](https://yazi-rs.github.io/) 是以 Rust 撰寫的極速終端機檔案管理器，
支援非同步 I/O。在 Ghostty 與 Kitty 中支援圖片預覽。

**功能特色：**

- **主題**: Catppuccin Mocha（與 Ghostty/Kitty/Neovim 統一風格）
- **Git 整合**: git.yazi 外掛在檔案旁顯示 git 狀態
- **Markdown 預覽**: piper.yazi 搭配 glow 渲染 markdown 預覽
- **HiDPI 預覽**: `max_width`/`max_height` 設為 16384，PDF 和圖片
  預覽在 Retina 螢幕上佔滿整個預覽欄
- **狀態列**: 顯示 symlink 指向路徑和檔案擁有者:群組
- **預覽品質**: `image_quality = 90` 搭配 `image_delay = 50` 防抖
- **圓角邊框**: full-border 外掛提供精緻外觀
- **檔案比較**: diff.yazi 快速比較檔案並產生 patch 到剪貼簿
- **智慧貼上**: 自動貼到 hover 的目錄或目前目錄
- **macOS 標籤**: mactag.yazi 整合 Finder 顏色標籤（Catppuccin 配色）
- **智慧外掛**: smart-enter、smart-filter、smart-paste、
  jump-to-char、toggle-pane、chmod、lazygit、compress

**快捷鍵：**

| 按鍵 | 動作 |
| --- | --- |
| `Enter` | 智慧進入（開檔或進目錄） |
| `f` | 跳到指定字元開頭的檔案（類似 Vim） |
| `F` | 即時互動過濾檔案 |
| `T` | 最大化預覽窗格 |
| `Ctrl+t` | 隱藏預覽窗格 |
| `Shift+j` | 預覽向下捲動（PDF 翻頁、程式碼、markdown） |
| `Shift+k` | 預覽向上捲動 |
| `g` 再按 `g` | 開啟 lazygit |
| `g` 再按 `d` | 跳至 ~/Downloads |
| `g` 再按 `p` | 跳至 ~/Projects |
| `g` 再按 `c` | 跳至 ~/.config |
| `g` 再按 `D` | 跳至 ~/Desktop |
| `g` 再按 `t` | 在目前目錄開啟 Ghostty |
| `c` 再按 `m` | 修改檔案權限 |
| `c` 再按 `a` | 壓縮選取的檔案 |
| `Ctrl+d` | 比較選取檔案與 hover 檔案 |
| `p` | 智慧貼上（貼到 hover 的目錄或目前目錄） |
| `b` 再按 `a` | 為選取檔案新增 macOS 標籤 |
| `b` 再按 `r` | 移除 macOS 標籤 |

```bash
# 開啟 yazi（使用 'y' 包裝函式，離開時 cd）
y

# 導航
# h/l 或 ←/→  - 上層/下層目錄
# j/k 或 ↑/↓  - 移動游標
# Enter       - 開啟檔案
# q           - 離開（不 cd）
# Shift+Q     - 離開（cd 至目前目錄，透過 'y' 包裝函式）
```

**設定檔結構：**

```text
~/.config/yazi/
├── yazi.toml      # 主設定（預覽、開啟方式、外掛 fetcher）
├── keymap.toml    # 自訂快捷鍵
├── theme.toml     # Catppuccin Mocha 主題
├── init.lua       # 狀態列、git、圓角邊框設定
├── package.toml   # 套件清單（ya pkg install/upgrade）
├── plugins/
│   └── (全部)     # 由 ya pkg 管理：git、smart-enter、
│                  # smart-filter、smart-paste、jump-to-char、
│                  # toggle-pane、chmod、diff、mactag、piper、
│                  # full-border、lazygit、compress
└── flavors/
    └── catppuccin-mocha.yazi/  # 主題風格
```

### Lazygit (Git TUI)

[Lazygit](https://github.com/jesseduffield/lazygit) 是 Git 的終端 UI。
已設定 Catppuccin Mocha 主題、delta 語法高亮差異檢視、Nerd Font 圖示
及圓角邊框。

**啟動：** `lazygit` 或在 Yazi 中按 `g g`。

| 按鍵 | 動作 |
| --- | --- |
| `space` | 暫存/取消暫存檔案 |
| `c` | 提交 |
| `p` / `P` | Pull / Push |
| `enter` | 檢視檔案差異（delta 語法高亮） |
| `[` / `]` | 切換面板 |
| `/` | 過濾 |
| `?` | 顯示所有快捷鍵 |
| `x` | 開啟目前面板的操作選單 |

### Mise 版本管理器

[Mise](https://mise.jdx.dev/) 管理每個專案的開發工具版本。
取代 nvm、pyenv、rbenv 等工具，提供統一的介面。

```bash
# 檢查已安裝的工具
mise ls

# 安裝特定版本
mise use node@22
mise use python@3.13

# 專案設定（在專案根目錄建立 .mise.toml）
mise use node@18    # 建立/更新 .mise.toml

# 全域設定
mise use -g node@lts python@3.13

# 讀取現有版本檔案（.nvmrc、.python-version 等）
```

設定檔：`~/.config/mise/config.toml`

## 手動更新

若偏好手動執行更新：

```bash
# Homebrew 更新
brew upgrade --yes
brew upgrade --cask --greedy-latest --yes

# Zinit 更新（在 zsh 中）
zinit update --all

# Bob 自我更新：從 dev 分支取得尚未發佈的上游修正
cargo install --git https://github.com/MordechaiHadad/bob \
    --branch dev --locked --force

# Bob nightly 更新（install 具冪等性；use 會重寫 proxy）
bob install nightly && bob use nightly

# LazyVim 更新（在 Neovim 中）
nvim --headless '+Lazy! sync' +qa
```

## 倉庫結構

```text
~/
├── .config/
│   ├── nvim/          # Neovim 設定 (LazyVim)
│   ├── zed/           # Zed 編輯器設定
│   ├── ghostty/       # Ghostty 終端機設定
│   ├── zellij/        # Zellij 多工器（設定、主題）
│   ├── yazi/          # Yazi 檔案管理器（主題、外掛、快捷鍵）
│   ├── kitty/         # Kitty 終端機設定
│   ├── git/config     # 共享 git 設定（yadm 追蹤；~/.gitconfig
│   │                  #   為本機專屬且已 gitignore）
│   ├── atuin/         # Atuin shell 歷史記錄
│   ├── mise/          # Mise 版本管理器
│   ├── sesh/          # Sesh 工作階段管理器
│   ├── lazygit/       # Lazygit TUI
│   ├── btop/          # Btop 資源監控器
│   ├── starship.toml  # Starship 提示列
│   ├── bat/           # Bat 主題
│   ├── ripgrep/       # Ripgrep 設定
│   └── yadm/
│       ├── bootstrap  # Clone 後設定腳本
│       └── hooks/
│           └── pre_commit  # Pre-commit 驗證（yadm 3.x 路徑）
├── .claude/           # Claude Code 共享設定、skills、主題
├── .ssh/
│   ├── config              # 模組化 SSH 設定的 Include 指令
│   └── config.d/
│       └── 00-defaults.conf  # 共用 SSH 預設值
├── .local/
│   └── bin/           # 使用者腳本
│       ├── battery-status        # 電池監控
│       ├── claude-name-session   # 自動命名 Claude Code 工作階段
│       ├── claude-notify         # OSC 9/777 桌面通知
│       ├── claude-statusline     # Claude Code 豐富狀態列
│       └── mkscript              # 新腳本鷹架
├── Library/
│   └── LaunchAgents/  # macOS 啟動代理
│       ├── com.daily-maintenance.plist##template  # yadm 範本
│       └── com.daily-maintenance.plist            # 產生的檔案（已 gitignore）
├── .tmux.conf         # Tmux 設定
├── .zshrc             # Zsh 設定
├── Brewfile           # Homebrew 套件清單
├── daily-maintenance.sh           # 主要維護腳本
├── daily-maintenance-lib.sh       # 共用輔助函式（路徑、launchctl）
├── daily-maintenance-control.sh   # 控制腳本
├── install-daily-maintenance.sh   # 安裝腳本
├── uninstall-daily-maintenance.sh # 解除安裝腳本
├── test-dotfiles.sh                # 本機測試套件
├── test-bootstrap.sh               # Bootstrap 測試套件
├── .github/
│   └── workflows/
│       └── ci.yml                  # CI/CD 流程
├── README.md                       # 英文文件
├── README.zh-TW.md                 # 繁體中文文件（本檔案）
└── CONTRIBUTING.md                 # 開發指南
```

## 更新 Dotfiles

```bash
# 拉取最新變更
yadm pull

# 檢查狀態
yadm status

# 新增並提交變更
yadm add <file>
yadm commit -m "變更說明"
yadm push
```

## 測試與 Linting

提交前執行測試：

```bash
# 執行完整測試套件
bash ~/test-dotfiles.sh

# 安裝 linter（使用 uv 加速）
brew install uv
uv tool install yamllint
uv tool install beautysh --with setuptools

# 執行個別 linter
yamllint -d relaxed .github/workflows/ci.yml
shellcheck *.sh  # 若已透過 brew 安裝
```

## 貢獻

歡迎 fork 並提交 pull request。一些指南：

- 提交前執行 `test-dotfiles.sh`
- 使用 conventional commit 訊息格式
- 為新腳本或設定撰寫文件

## 授權條款

個人 dotfiles — 使用風險自負。歡迎參考或複製您需要的部分。

## 致謝

- [yadm](https://yadm.io/) — Dotfile 管理
- [LazyVim](https://www.lazyvim.org/) — Neovim 設定
- [zinit](https://github.com/zdharma-continuum/zinit) — Zsh 外掛管理
- [bob](https://github.com/MordechaiHadad/bob) — Neovim 版本管理
  （透過 cargo 追蹤上游 `dev` 分支）

---

最後更新：2026 年 7 月
