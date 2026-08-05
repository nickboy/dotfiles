# 每日維護自動化

## 概覽

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

## 功能特色

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

## 安裝每日維護

### 自動安裝

```bash
# 執行安裝腳本
bash ~/install-daily-maintenance.sh
```

### 手動安裝

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

## 使用方式

### 快速存取別名（在 .zshrc 中設定）

```bash
# 日常操作快捷鍵
mr  # 手動執行維護（跳過日期檢查）
ms  # 檢查維護狀態
ml  # 查看維護日誌
```

### 完整控制指令

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

## 設定

### 變更排程

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

### 新增指令

編輯 `~/daily-maintenance.sh`，依照現有模式新增指令：

```bash
if ! run_command "描述" your-command --args; then
    FAILED_COMMANDS+=("your-command")
fi
```

## 疑難排解

### 檢查自動化是否正在執行

```bash
launchctl list | grep daily-maintenance
```

### 查看最新日誌

```bash
tail -f ~/Library/Logs/daily-maintenance.log
```

### 查看錯誤日誌

```bash
tail -f ~/Library/Logs/daily-maintenance-error.log
```

### 重設自動化

```bash
~/daily-maintenance-control.sh stop
~/daily-maintenance-control.sh start
```

## 解除安裝

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
