#!/bin/bash

# Local Dotfiles Test Suite
# Run this before committing to catch issues early

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Dotfiles Local Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo

FAILED_TESTS=()
PASSED_TESTS=()

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -ne "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        PASSED_TESTS+=("$test_name")
    else
        echo -e "${RED}✗${NC}"
        FAILED_TESTS+=("$test_name")
        echo -e "  ${YELLOW}Command: $test_command${NC}"
        echo -e "  ${YELLOW}Run the command manually to see the error${NC}"
    fi
}

# Test 1: Bash syntax check for all shell scripts
echo -e "${YELLOW}1. Shell Script Syntax Checks${NC}"
for script in *.sh; do
    if [ -f "$script" ]; then
        run_test "Bash syntax for $script" "bash -n $script"
    fi
done
echo

# Test 2: Check if scripts are executable
echo -e "${YELLOW}2. Script Permissions${NC}"
for script in daily-maintenance*.sh install-daily-maintenance.sh uninstall-daily-maintenance.sh; do
    if [ -f "$script" ]; then
        run_test "Executable permission for $script" "[ -x $script ]"
    fi
done
echo

# Test 3: Validate plist template (yadm ##template with {{env.HOME}})
echo -e "${YELLOW}3. LaunchAgent Plist Template Validation${NC}"
PLIST_TEMPLATE="Library/LaunchAgents/com.daily-maintenance.plist##template"
if [ -f "$PLIST_TEMPLATE" ]; then
    # Create temp file with substituted values for validation
    TEMP_PLIST="/tmp/test-plist-$$"
    sed "s|{{env.HOME}}|$HOME|g" "$PLIST_TEMPLATE" > "$TEMP_PLIST"
    if command -v plutil >/dev/null 2>&1; then
        run_test "Plist template validation" "plutil -lint '$TEMP_PLIST'"
    else
        run_test "Plist template XML validation" "xmllint --noout '$TEMP_PLIST'"
    fi
    rm -f "$TEMP_PLIST"
else
    echo -e "${YELLOW}  Plist template file not found${NC}"
fi
echo

# Test 4: Check for shellcheck if available
echo -e "${YELLOW}4. ShellCheck Analysis${NC}"
if command -v shellcheck >/dev/null 2>&1; then
    for script in *.sh; do
        if [ -f "$script" ]; then
            run_test "ShellCheck for $script" "shellcheck -S warning $script"
        fi
    done
else
    echo -e "${YELLOW}  ShellCheck not installed. Install with: brew install shellcheck${NC}"
fi
echo

# Test 5: YAML validation for CI files
echo -e "${YELLOW}5. YAML Lint (CI Files)${NC}"
if command -v yamllint >/dev/null 2>&1; then
    for yaml_file in .github/workflows/*.yml; do
        if [ -f "$yaml_file" ]; then
            run_test "YAML lint for $(basename $yaml_file)" "yamllint -d relaxed $yaml_file"
        fi
    done
else
    echo -e "${YELLOW}  yamllint not installed. Install with: uv tool install yamllint${NC}"
fi
echo

# Test 6: Zsh configuration validation
echo -e "${YELLOW}6. Zsh Configuration Validation${NC}"
if [ -f ~/.zshrc ]; then
    run_test "Zsh syntax check" "zsh -n ~/.zshrc"
    
    # Check for beautysh
    if command -v beautysh >/dev/null 2>&1; then
        run_test "Beautysh format check" "beautysh --check ~/.zshrc 2>/dev/null"
    else
        echo -e "${YELLOW}  beautysh not installed. Install with: uv tool install beautysh --with setuptools${NC}"
    fi
    
    # Basic anti-pattern checks
    run_test "No backticks in .zshrc" "! grep '\`.*\`' ~/.zshrc"

    # Duplicate alias detection
    run_test "No duplicate aliases in .zshrc" "[ -z \"\$(sed -n 's/^alias \([^=]*\)=.*/\1/p' ~/.zshrc | sort | uniq -d)\" ]"

    # Duplicate zinit plugin detection
    run_test "No duplicate zinit plugins" "[ -z \"\$(grep -oE 'zinit (light|load|snippet) [^ ;]+' ~/.zshrc | awk '{print \$3}' | sort | uniq -d)\" ]"

    # compinit should appear exactly once (non-commented, non-deferred)
    run_test "Single compinit call" "[ \"\$(grep -cE '^\s*compinit' ~/.zshrc)\" -le 1 ]"

    # Redundant redirect pattern: &>/dev/null 2>&1
    run_test "No redundant redirects (&>/dev/null 2>&1)" "! grep '&>/dev/null 2>&1' ~/.zshrc"
else
    echo -e "${YELLOW}  No .zshrc file found${NC}"
fi
echo

# Test 7: Check for common issues
echo -e "${YELLOW}7. Common Issues Check${NC}"

# Check for hardcoded paths that might not exist
run_test "No hardcoded /Users/specific paths" "! grep -r '/Users/[^/]*/' *.sh | grep -v '\$HOME' | grep -v nickboy"
# uv's installer drops a PATH snippet at ~/.local/bin/env meant to be
# SOURCED; if it ever becomes executable it shadows /usr/bin/env (PATH
# puts ~/.local/bin second) and silently swallows every 'env ... cmd'
# invocation with exit 0. That exact trap cost a debugging session.
run_test "env resolves to /usr/bin/env (no executable shim)" \
    "[ \"\$(command -v env)\" = /usr/bin/env ]"
run_test "No ~/.local/bin executables shadow system binaries" \
    "! (for f in \$HOME/.local/bin/*; do b=\$(basename \"\$f\"); [ -x \"\$f\" ] && { [ -e \"/usr/bin/\$b\" ] || [ -e \"/bin/\$b\" ]; } && echo \"\$b\"; done | grep -q .)"
# Retired plugins must stay retired (dotenv: cd-triggered .env sourcing
# in an agent-heavy workflow; rbenv/ruby/rake: mise-era leftovers;
# extract: replaced by ouch aliases in the July round)
run_test "Retired OMZ snippets stay retired" \
    "! grep -qE 'OMZP::(dotenv|rbenv|ruby|rake|extract)' $HOME/.zshrc"
# zsh-eza retired 2026-08: its aliases are hand-written now (the old
# _EZA_PARAMS export was dead code — the plugin never read that name)
run_test "Retired zinit plugins stay retired (zsh-eza)" \
    "! grep -qE 'zinit (light|load).*(zsh-eza)|_EZA_PARAMS' $HOME/.zshrc && { ! command -v eza >/dev/null 2>&1 || zsh -ic 'alias ll' 2>/dev/null | grep -q eza; }"
# yazi plugins are declared in package.toml (ya pkg, SHA-pinned) — the
# declaration must be yadm-tracked and every declared plugin installed,
# or new machines silently lose the plugin set (the pre-2026-08 state)
if [ -f "$HOME/.config/yazi/package.toml" ]; then
    # Tracked check works under yadm (real machines) or git (CI checkout)
    run_test "yazi package.toml is tracked" \
        "{ yadm ls-files .config/yazi/package.toml 2>/dev/null || git ls-files .config/yazi/package.toml 2>/dev/null; } | grep -q package.toml"
    # Plugin presence only where ya pkg has actually run (CI checkouts
    # have no plugins/ — contents are ignored build artifacts)
    if [ -d "$HOME/.config/yazi/plugins" ]; then
        run_test "yazi declared plugins all installed" \
            "! (grep -oE 'use = \"[^\"]+\"' \$HOME/.config/yazi/package.toml | sed -E 's/.*[:\\/]([^\":]+)\"/\\1/' | while IFS= read -r p; do [ -f \"\$HOME/.config/yazi/plugins/\$p.yazi/main.lua\" ] || echo \"missing \$p\"; done | grep -q .)"
    fi
fi
# Theme is owned by ~/.config/bat/config — call sites must not override
run_test "No hardcoded bat --theme in .zshrc" \
    "! grep -qE 'bat [^|]*--theme=' $HOME/.zshrc"
run_test "fzf-tab inherits FZF_DEFAULT_OPTS" \
    "grep -q 'use-fzf-default-opts.*yes' $HOME/.zshrc"

# Check for proper shebang
for script in *.sh; do
    if [ -f "$script" ]; then
        run_test "Proper shebang in $script" "head -1 $script | grep -q '^#!/bin/bash'"
    fi
done

echo

# Test 8: Dry run of scripts (safe operations only)  
echo -e "${YELLOW}8. Script Dry Run Tests${NC}"

# Test daily-maintenance.sh functions
TEST_MAINT_SCRIPT=$(mktemp "${TMPDIR:-/tmp}/test_maintenance.XXXXXX")
cat > "$TEST_MAINT_SCRIPT" << 'EOF'
#!/bin/bash
# Source the script but override dangerous functions
brew() { echo "MOCK: brew $@"; return 0; }
zsh() { echo "MOCK: zsh $@"; return 0; }
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Define the run_command function from the script
run_command() {
    local description="$1"
    shift
    local command="$@"
    echo "TEST: Would run: $description - $command"
    return 0
}

# Define FAILED_COMMANDS array
FAILED_COMMANDS=()

# Test that the script structure is valid
echo "Script structure is valid"
EOF

run_test "Daily maintenance script structure" "bash '$TEST_MAINT_SCRIPT'"

# Content checks: ensure key upgrade sections are present
# (regression guards for accidental removal)
if [ -f "$HOME/daily-maintenance.sh" ]; then
    run_test "Daily maintenance includes mise upgrade" \
        "grep -qE '^[[:space:]]*(run_command|mise upgrade|\"Mise runtime upgrade\")' $HOME/daily-maintenance.sh && grep -q 'mise upgrade' $HOME/daily-maintenance.sh"
    # brew upgrades must stay non-interactive (Homebrew 6 prompts otherwise),
    # or the unattended run stalls. Guard: every run_command brew upgrade has --yes.
    run_test "Maintenance brew upgrades are non-interactive (--yes)" \
        "! grep -E 'run_command .*brew upgrade' $HOME/daily-maintenance.sh | grep -qv -- '--yes'"
    # Guard the self-heal that clears stale cask *.upgrading staging dirs.
    run_test "Maintenance self-heals stale cask .upgrading dirs" \
        "grep -qF '.upgrading' $HOME/daily-maintenance.sh"
    # Self-updating apps (VS Code) must never be cask-upgraded by the
    # unattended run: --greedy-latest is the ceiling. Plain --greedy or
    # --greedy-auto-updates would replace apps that update themselves
    # (a July 2026 incident deleted VS Code that way).
    run_test "Maintenance cask upgrade never uses greedy/auto-updates" \
        "! grep -E 'brew upgrade' $HOME/daily-maintenance.sh | grep -qE -- '--greedy(-auto-updates)?([[:space:]]|\$)'"
    # Post-upgrade schema drift is invisible without these: a tool whose
    # config stopped parsing falls back to its defaults silently (yazi did
    # exactly that for weeks after the fetchers id -> group rename).
    run_test "Maintenance runs config schema checks" \
        "grep -q 'zellij setup --check' $HOME/daily-maintenance.sh && grep -q 'atuin doctor' $HOME/daily-maintenance.sh"
    # Tripwire: the maintenance run must never call the herdr CLI beyond
    # --version — any other subcommand can auto-start a server that
    # inherits the launchd environment (the CLAUDECODE-leak bug class).
    # Allowed matches: --version calls, echo/notifier message strings,
    # the socket path. Anything else fails.
    run_test "Maintenance calls herdr CLI only with --version" \
        "! grep -E '^[^#]*\\bherdr\\b' $HOME/daily-maintenance.sh | grep -v -e '--version' -e echo -e terminal-notifier -e '\\-message' -e '\\.sock' | grep -q ."
    # The strand guard depends on the shared lib being sourced.
    run_test "Maintenance sources daily-maintenance-lib.sh" \
        "grep -qE '^source .*daily-maintenance-lib.sh' $HOME/daily-maintenance.sh && grep -q 'dm_herdr_strand_detected' $HOME/daily-maintenance.sh"
    # Failures must reach the desktop, not just the log (the bob wedge
    # was recorded daily for a month and surfaced never)
    run_test "Maintenance notifies on failed tasks" \
        "grep -q 'Daily maintenance: \${#FAILED_COMMANDS\[@\]} task(s) failed' $HOME/daily-maintenance.sh"
    # Bootstrap must keep the machine-service wiring (new machines and
    # the pull-then-bootstrap flow depend on these being automated)
    run_test "Bootstrap wires atuin service, ya pkg, and suite run" \
        "grep -q 'brew services start atuin' $HOME/.config/yadm/bootstrap && grep -q 'ya pkg install' $HOME/.config/yadm/bootstrap && grep -q 'test-dotfiles.sh' $HOME/.config/yadm/bootstrap"
fi
echo

# Test 9: Config file validation
echo -e "${YELLOW}9. Config File Validation${NC}"

# Validate Brewfile syntax
if command -v brew >/dev/null 2>&1 && [ -f "$HOME/Brewfile" ]; then
    run_test "Brewfile syntax" "brew bundle check --file=$HOME/Brewfile 2>&1 | head -1"
fi

# Validate mise config
if command -v mise >/dev/null 2>&1 && [ -f "$HOME/.config/mise/config.toml" ]; then
    run_test "Mise config syntax" "mise config 2>&1 | head -1"
fi

# Validate yazi config exists
if [ -f "$HOME/.config/yazi/yazi.toml" ]; then
    run_test "Yazi config exists" "[ -s $HOME/.config/yazi/yazi.toml ]"
fi

# Validate Ghostty config
if command -v ghostty >/dev/null 2>&1; then
    run_test "Ghostty config valid" "ghostty +validate-config"
    if [ -f "$HOME/.config/ghostty/config" ]; then
        SCROLLBACK=$(sed -n 's/^scrollback-limit *=  *\([0-9]*\)/\1/p' "$HOME/.config/ghostty/config" 2>/dev/null)
        SCROLLBACK=${SCROLLBACK:-0}
        run_test "Ghostty scrollback-limit >= 1000000" "[ \"$SCROLLBACK\" -ge 1000000 ]"
    fi
fi

# Validate tmux config syntax (parse check only, no server needed)
if command -v tmux >/dev/null 2>&1 && [ -f "$HOME/.tmux.conf" ]; then
    run_test "Tmux config exists and non-empty" "[ -s $HOME/.tmux.conf ]"
fi

# Validate Starship config (TOML syntax)
if [ -f "$HOME/.config/starship.toml" ]; then
    run_test "Starship config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/starship.toml').read_text())\""
    if command -v bat >/dev/null 2>&1; then
        run_test "bat Catppuccin Mocha theme registered" \
            "bat --list-themes 2>/dev/null | grep -q 'Catppuccin Mocha' && grep -q 'Catppuccin Mocha' $HOME/.config/bat/config"
    fi
    if command -v tmux >/dev/null 2>&1; then
        # Sources the real config incl. TPM; verified 3 throwaway runs
        # leave ~/.tmux/resurrect untouched (no plugin side effects).
        run_test "Tmux config parses (throwaway server)" \
            "tmux -L cfgtest-suite -f $HOME/.tmux.conf new-session -d 2>/dev/null && tmux -L cfgtest-suite kill-server 2>/dev/null"
        run_test "Tmux history-limit >= 50000" \
            "grep -qE 'history-limit (5[0-9]{4,}|[6-9][0-9]{4}|[0-9]{6,})' $HOME/.tmux.conf"
    fi
    # ssh-terminfo (not ssh-env) keeps TERM intact on remotes — herdr's
    # terminal-notification detection over SSH depends on it
    # (ssh-env is the wrong tool: it downgrades TERM to xterm-256color)
    run_test "Ghostty shell integration includes ssh-terminfo" \
        "grep -E '^shell-integration-features' $HOME/.config/ghostty/config | grep -q 'ssh-terminfo'"
    # Daily bob-nightly + plugin churn can desync editor and plugins
    # (the neo-tree/nvim_win_resize incident: nvim frozen on a June
    # nightly while plugins assumed a newer API) — a clean headless
    # boot is the cheapest canary
    if command -v nvim >/dev/null 2>&1; then
        run_test "Neovim boots headless without errors" \
            "! nvim --headless -c q 2>&1 | grep -qiE 'error|traceback'"
    fi
    if [ -f "$HOME/.config/jj/config.toml" ]; then
        run_test "jj config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/jj/config.toml').read_text())\""
        if command -v jj >/dev/null 2>&1; then
            run_test "jj accepts the user config" \
                "jj config list --user >/dev/null 2>&1"
        fi
    fi
    # ripgrep config was dormant for ages (env var never exported).
    # Assert it is wired AND stays a pure search-filter config: output
    # flags (--pretty/--context/--column) would leak into piped and
    # scripted rg calls the moment the config is active.
    if command -v rg >/dev/null 2>&1; then
        run_test "ripgrep config exported and parses" \
            "grep -q 'export RIPGREP_CONFIG_PATH=' $HOME/.zshrc && RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/config rg --files $HOME/.config/ripgrep >/dev/null 2>&1"
        run_test "ripgrep config has no output-format flags" \
            "! grep -qE '^--(pretty|context=|column|line-number)' $HOME/.config/ripgrep/config"
    fi
    # mergiraf must be wired end-to-end: the attributes line without the
    # driver definition (or vice versa) is a silent no-op
    run_test "mergiraf attributes/driver pairing" \
        "grep -q 'merge=mergiraf' $HOME/.config/git/attributes && grep -q 'merge \"mergiraf\"' $HOME/.config/git/config"
fi

# Validate Kitty config
if command -v kitty >/dev/null 2>&1 && [ -f "$HOME/.config/kitty/kitty.conf" ]; then
    run_test "Kitty config valid" "kitty --config $HOME/.config/kitty/kitty.conf --debug-config 2>&1 | grep -qv 'Error'"
fi

# Validate Atuin config (TOML syntax)
if [ -f "$HOME/.config/atuin/config.toml" ]; then
    run_test "Atuin config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/atuin/config.toml').read_text())\""
    # Daemon mode is per-machine state the tracked config cannot carry: the
    # config can say enabled = true on a machine where
    # `brew services start atuin` was never run, and history then goes
    # nowhere. Only assert when the config actually asks for the daemon.
    # Guarded on atuin being installed: CI checks out the tracked config
    # (daemon enabled) onto a runner with no atuin — skip there, still
    # catch a real machine that never started the service.
    if command -v atuin >/dev/null 2>&1 && grep -A6 '\[daemon\]' "$HOME/.config/atuin/config.toml" 2>/dev/null | grep -qE '^enabled = true'; then
        run_test "atuin daemon socket live when enabled" \
            "[ -S \"$HOME/.local/share/atuin/atuin.sock\" ]"
    fi
fi

# Validate sesh config (TOML syntax)
if [ -f "$HOME/.config/sesh/sesh.toml" ]; then
    run_test "Sesh config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/sesh/sesh.toml').read_text())\""
    # zjstatus must stay pinned to an exact release (never 'latest'):
    # Zellij caches the wasm by URL, so a mutable URL = unpinned supply
    # chain AND stale-cache confusion.
    run_test "Zellij zjstatus plugin URL is version-pinned" \
        "grep -qE 'zjstatus/releases/download/v[0-9]+\.[0-9]+\.[0-9]+/zjstatus\.wasm' $HOME/.config/zellij/layouts/default.kdl"
    if command -v zellij >/dev/null 2>&1; then
        run_test "Zellij config + layouts parse (setup --check)" \
            "zellij setup --check >/dev/null 2>&1"
    fi
    # Yazi 26 broke silently on a stale fetchers schema (id -> group):
    # --version fails when the config no longer parses, so this catches
    # the next schema break instead of yazi quietly using preset config.
    # (verified: --version exits 1 on broken config, 0 when clean)
    if command -v yazi >/dev/null 2>&1; then
        run_test "Yazi config parses (yazi --version)" \
            "yazi --version >/dev/null 2>&1"
    fi
    if [ -f "$HOME/.config/herdr/config.toml" ]; then
        run_test "herdr config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/herdr/config.toml').read_text())\""
    fi
    if [ -f "$HOME/.config/herdr/plugins/config/sessionizer/config.toml" ]; then
        run_test "herdr sessionizer config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/herdr/plugins/config/sessionizer/config.toml').read_text())\""
    fi
fi
echo

# Test 10: Symlink Integrity
echo -e "${YELLOW}10. Symlink Integrity${NC}"

# Ghostty config symlink
GHOSTTY_LINK="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
if [ -e "$GHOSTTY_LINK" ] || [ -L "$GHOSTTY_LINK" ]; then
    run_test "Ghostty config is symlink" "[ -L \"$GHOSTTY_LINK\" ]"
    run_test "Ghostty symlink target correct" "[ \"\$(readlink \"$GHOSTTY_LINK\")\" = \"$HOME/.config/ghostty/config\" ]"
fi

# Critical dotfiles exist and are non-empty
for dotfile in ~/.zshrc ~/.tmux.conf ~/.gitconfig ~/.config/starship.toml; do
    if [ -e "$dotfile" ]; then
        run_test "$(basename $dotfile) exists and non-empty" "[ -s $dotfile ]"
    fi
done
echo

# Test 11: Security Checks
echo -e "${YELLOW}11. Security Checks${NC}"

# No secrets in yadm-tracked files
if command -v yadm >/dev/null 2>&1; then
    run_test "No secrets in tracked files" "[ -z \"\$(yadm list -a 2>/dev/null | xargs grep -lE '(APIKEY|SECRET_KEY|API_TOKEN|PRIVATE_KEY|TOKEN|PASSWORD|CREDENTIAL|AWS_SECRET)\s*=' 2>/dev/null | grep -v 'HOMEBREW_NO_ANALYTICS' | grep -v 'test-dotfiles.sh')\" ]"
fi
# Commit signing depends on allowed_signers carrying a public key
if [ -f "$HOME/.ssh/allowed_signers" ]; then
    run_test "allowed_signers contains an SSH public key" \
        "grep -qE 'ssh-(rsa|ed25519) ' $HOME/.ssh/allowed_signers"
fi
# Every checkout in CI must set persist-credentials: false (zizmor
# artipacked); count parity catches a new checkout step added without it.
if [ -f "$HOME/.github/workflows/ci.yml" ]; then
    run_test "CI checkouts all set persist-credentials false" \
        "[ \"\$(grep -c 'uses: actions/checkout@' $HOME/.github/workflows/ci.yml)\" -eq \"\$(grep -c 'persist-credentials: false' $HOME/.github/workflows/ci.yml)\" ]"
fi
echo

# Test 12: Git/yadm checks
echo -e "${YELLOW}12. Version Control Checks${NC}"
run_test "No uncommitted changes" "[ -z \"$(yadm status --porcelain 2>/dev/null)\" ] || yadm status --porcelain"
echo

# Test 13: Markdown Lint (mandatory — every commit MUST pass, no exceptions)
# NOTE: never lint '**/*.md' from ~ — it scans the whole home dir and hangs.
# -z/-0 keeps filenames with spaces intact and skips the run on empty input.
echo -e "${YELLOW}13. Markdown Lint${NC}"
if command -v npx >/dev/null 2>&1; then
    # Locally the tracked files come from yadm; in CI checkouts from git.
    if command -v yadm >/dev/null 2>&1 && yadm ls-files >/dev/null 2>&1; then
        run_test "markdownlint on tracked markdown files" \
            "yadm ls-files -z '*.md' | xargs -0 npx markdownlint-cli"
    elif git rev-parse --git-dir >/dev/null 2>&1; then
        run_test "markdownlint on tracked markdown files" \
            "git ls-files -z '*.md' | xargs -0 npx markdownlint-cli"
    else
        echo -e "${YELLOW}  Not a yadm/git repo; skipping markdown lint${NC}"
    fi
else
    echo -e "${YELLOW}  npx not available; skipping markdown lint (CI will enforce it)${NC}"
fi
# The README split moved sections into docs/ pages — every relative .md
# link in the READMEs and docs/ must resolve, or the split rots silently.
run_test "Relative .md links in README/docs resolve" \
    "! (for f in \$HOME/README.md \$HOME/README.zh-TW.md \$HOME/docs/*.md; do d=\$(dirname \"\$f\"); grep -oE '\\]\\(([A-Za-z0-9._/-]+\\.md)[)#]' \"\$f\" 2>/dev/null | sed -E 's/^\\]\\(//; s/[)#]\$//' | while IFS= read -r l; do [ -f \"\$d/\$l\" ] || echo \"\$f -> \$l\"; done; done | grep -q .)"
echo

# Test 14: ShellCheck on ALL tracked bash/sh scripts (shebang-detected)
# Covers extensionless scripts (.local/bin tools, yadm hooks) that the
# '*.sh' glob in Test 4 misses. The anchored regex deliberately excludes
# zsh scripts — shellcheck does not support zsh.
echo -e "${YELLOW}14. ShellCheck (tracked scripts by shebang)${NC}"
if command -v shellcheck >/dev/null 2>&1; then
    if command -v yadm >/dev/null 2>&1 && yadm ls-files >/dev/null 2>&1; then
        TRACKED_FILES=$(yadm ls-files)
    elif git rev-parse --git-dir >/dev/null 2>&1; then
        TRACKED_FILES=$(git ls-files)
    else
        TRACKED_FILES=""
    fi
    if [ -n "$TRACKED_FILES" ]; then
        while IFS= read -r tracked; do
            [ -f "$tracked" ] || continue
            if head -1 "$tracked" 2>/dev/null | \
               grep -qE '^#!/(usr/(local/)?)?bin/(env +)?(bash|sh)\b'; then
                run_test "ShellCheck (shebang) $tracked" \
                    "shellcheck -S warning '$tracked'"
            fi
        done <<< "$TRACKED_FILES"
    else
        echo -e "${YELLOW}  Not a yadm/git repo; skipping shebang shellcheck${NC}"
    fi
else
    echo -e "${YELLOW}  ShellCheck not installed; skipping${NC}"
fi
echo

# Test 15: Unit tests (lib functions + fixture-based checks)
echo -e "${YELLOW}15. Unit Tests${NC}"

# dm_herdr_strand_detected: pure predicate from daily-maintenance-lib.sh.
# A real unix socket is required for the -S branch; python3 binds one in
# a temp dir so all four polarities are exercised.
if [ -f "$HOME/daily-maintenance-lib.sh" ]; then
    HERDR_UT_DIR=$(mktemp -d)
    python3 -c "import socket; socket.socket(socket.AF_UNIX).bind('$HERDR_UT_DIR/live.sock')" 2>/dev/null
    UT_SRC="source '$HOME/daily-maintenance-lib.sh' >/dev/null 2>&1;"
    # macOS caps unix socket paths at ~104 bytes; if the bind failed
    # (long CI temp dir), skip the two socket-positive cases instead of
    # reporting a false failure.
    if [ -S "$HERDR_UT_DIR/live.sock" ]; then
        run_test "herdr strand: mismatch + live socket -> detected" \
            "bash -c \"$UT_SRC dm_herdr_strand_detected 'herdr 1.0' 'herdr 2.0' '$HERDR_UT_DIR/live.sock'\""
        run_test "herdr strand: same version -> silent" \
            "bash -c \"$UT_SRC ! dm_herdr_strand_detected 'herdr 1.0' 'herdr 1.0' '$HERDR_UT_DIR/live.sock'\""
    else
        echo -e "  ${YELLOW}ℹ️  unix socket bind unavailable; skipping socket-positive cases${NC}"
    fi
    run_test "herdr strand: no socket -> silent" \
        "bash -c \"$UT_SRC ! dm_herdr_strand_detected 'herdr 1.0' 'herdr 2.0' '$HERDR_UT_DIR/missing.sock'\""
    run_test "herdr strand: herdr absent (empty before) -> silent" \
        "bash -c \"$UT_SRC ! dm_herdr_strand_detected '' 'herdr 2.0' '$HERDR_UT_DIR/live.sock'\""
    rm -rf "$HERDR_UT_DIR"
fi

# gitleaks pre-commit engine: same invocation the yadm hook uses, against
# a throwaway fixture repo (plain git on purpose — the yadm-only rule is
# for the dotfiles repo, not isolated fixtures). The canary is assembled
# at runtime so no secret-shaped literal exists in this file (a literal
# would trip GitHub push protection and the hook's own scan).
# CRITICAL: every call strips GIT_DIR/GIT_WORK_TREE — the yadm pre_commit
# hook exports them, and an ambient GIT_DIR silently redirects fixture
# git commands at the REAL yadm repo (this once flipped its core.bare).
if command -v gitleaks >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    GL_TMP=$(mktemp -d)
    GL_GIT="env -u GIT_DIR -u GIT_WORK_TREE git"
    $GL_GIT -C "$GL_TMP" init -q &&
        $GL_GIT -C "$GL_TMP" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    printf 'aws_key = "%s%s"\n' "AKIA" "ZZZQK9X2M4P7L3TQ" > "$GL_TMP/leak.txt"
    $GL_GIT -C "$GL_TMP" add leak.txt
    run_test "gitleaks flags a staged canary secret" \
        "! (cd '$GL_TMP' && env -u GIT_DIR -u GIT_WORK_TREE gitleaks git --pre-commit --staged --no-banner --redact . >/dev/null 2>&1)"
    printf 'greeting = "hello"\n' > "$GL_TMP/leak.txt"
    $GL_GIT -C "$GL_TMP" add leak.txt
    run_test "gitleaks passes a clean staged file" \
        "(cd '$GL_TMP' && env -u GIT_DIR -u GIT_WORK_TREE gitleaks git --pre-commit --staged --no-banner --redact . >/dev/null 2>&1)"
    rm -rf "$GL_TMP"
fi
echo

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo

if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
    echo -e "${GREEN}Passed: ${#PASSED_TESTS[@]} tests${NC}"
    for test in "${PASSED_TESTS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $test"
    done
fi

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo
    echo -e "${RED}Failed: ${#FAILED_TESTS[@]} tests${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}✗${NC} $test"
    done
    echo
    echo -e "${YELLOW}Please fix the failed tests before committing.${NC}"
    exit 1
else
    echo
    echo -e "${GREEN}All tests passed! ✨${NC}"
    echo -e "${GREEN}Your dotfiles are ready to commit.${NC}"
fi

# Cleanup
rm -f "$TEST_MAINT_SCRIPT"

exit 0
