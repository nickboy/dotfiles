# Zed Editor 配置同步指南

## 📦 包含的配置

- `settings.json` - 主要設定檔（包含所有擴展自動安裝清單）
- `themes/` - 自訂主題（如有）

## 🚀 在新電腦上設定

### 1. 安裝 Zed
```bash
# macOS
brew install --cask zed

# 或從官網下載
# https://zed.dev
```

### 2. 使用 yadm 同步配置
```bash
# 安裝 yadm（如果還沒有）
brew install yadm

# Clone 你的 dotfiles
yadm clone https://github.com/YOUR_USERNAME/dotfiles.git

# 配置會自動同步到 ~/.config/zed/
```

### 3. 安裝必要的字體
```bash
# JetBrains Mono（主要字體）
brew install --cask font-jetbrains-mono
```

### 4. 安裝格式化工具
```bash
# Google Java Format
brew install google-java-format

# Python formatter (ruff)
pip install ruff

# Prettier (for JS/TS/HTML/CSS)
npm install -g prettier

# 其他語言的格式化器會由 LSP 自動處理
```

## 🎯 擴展會自動安裝

以下擴展會在首次開啟 Zed 時自動安裝：

### 語言支援
- `html` - HTML 語言支援
- `php` - PHP 語言支援
- `java` - Java 語言支援
- `yaml` - YAML 語言支援
- `xml` - XML 語言支援
- `sql` - SQL 語言支援
- `dockerfile` - Docker 支援
- `toml` - TOML 語言支援
- `latex` - LaTeX 支援

### 主題與圖示
- `catppuccin` - Catppuccin 主題系列
- `catppuccin-icons` - Catppuccin 圖示主題
- `material-icon-theme` - Material 圖示主題
- `tokyo-night` - Tokyo Night 主題

### AI 與工具
- `mcp-server-context7` - AI 上下文管理

## 📝 自訂設定

如需修改設定，編輯 `settings.json`：
```bash
zed ~/.config/zed/settings.json
```

## 🔄 更新配置到 yadm

```bash
# 加入變更
yadm add ~/.config/zed/settings.json

# 提交變更
yadm commit -m "Update Zed settings"

# 推送到遠端
yadm push
```

## ⚙️ 重要設定說明

- **Vim 模式**：已啟用，使用 VSCode 鍵盤映射為基礎
- **主題**：One Dark（可在設定中更改）
- **字體**：JetBrains Mono 15px
- **自動格式化**：儲存時自動格式化
- **行寬限制**：120 字元
- **Tab 大小**：2 空格（JS/TS/HTML/CSS）、4 空格（Python/Java/Go/Rust）

## 🐛 疑難排解

### 擴展沒有自動安裝？
1. 重啟 Zed
2. 開啟對應類型的檔案（如 .java 檔案會觸發 Java 擴展安裝）
3. 手動安裝：`Cmd+Shift+P` → 輸入擴展名稱

### 字體顯示問題？
確認 JetBrains Mono 已安裝：
```bash
ls ~/Library/Fonts/ | grep JetBrains
```

### 格式化不工作？
檢查對應的格式化工具是否已安裝（見上方安裝指令）
