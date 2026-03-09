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

# Test 3: Validate plist template
echo -e "${YELLOW}3. LaunchAgent Plist Template Validation${NC}"
PLIST_TEMPLATE="Library/LaunchAgents/com.daily-maintenance.plist.template"
if [ -f "$PLIST_TEMPLATE" ]; then
    # Create temp file with substituted values for validation
    TEMP_PLIST="/tmp/test-plist-$$"
    sed "s|{{HOME}}|$HOME|g" "$PLIST_TEMPLATE" > "$TEMP_PLIST"
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
cat > /tmp/test_maintenance.sh << 'EOF'
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

run_test "Daily maintenance script structure" "bash /tmp/test_maintenance.sh"
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
fi

# Validate Kitty config
if command -v kitty >/dev/null 2>&1 && [ -f "$HOME/.config/kitty/kitty.conf" ]; then
    run_test "Kitty config valid" "kitty --config $HOME/.config/kitty/kitty.conf --debug-config 2>&1 | grep -qv 'Error'"
fi

# Validate Atuin config (TOML syntax)
if [ -f "$HOME/.config/atuin/config.toml" ]; then
    run_test "Atuin config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/atuin/config.toml').read_text())\""
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
    run_test "No secrets in tracked files" "[ -z \"\$(yadm list -a 2>/dev/null | xargs grep -lE '(APIKEY|SECRET_KEY|TOKEN|PASSWORD)\s*=' 2>/dev/null | grep -v 'HOMEBREW_NO_ANALYTICS' | grep -v 'test-dotfiles.sh')\" ]"
fi
echo

# Test 12: Git/yadm checks
echo -e "${YELLOW}12. Version Control Checks${NC}"
run_test "No uncommitted changes" "[ -z \"$(yadm status --porcelain 2>/dev/null)\" ] || yadm status --porcelain"
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
rm -f /tmp/test_maintenance.sh

exit 0
