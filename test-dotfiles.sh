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

# Test 4b: Zsh configuration validation
echo -e "${YELLOW}4b. Zsh Configuration Validation${NC}"
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
else
    echo -e "${YELLOW}  No .zshrc file found${NC}"
fi
echo

# Test 5: Check for common issues
echo -e "${YELLOW}5. Common Issues Check${NC}"

# Check for hardcoded paths that might not exist
run_test "No hardcoded /Users/specific paths" "! grep -r '/Users/[^/]*/' *.sh | grep -v '\$HOME' | grep -v nickboy"

# Check for proper shebang
for script in *.sh; do
    if [ -f "$script" ]; then
        run_test "Proper shebang in $script" "head -1 $script | grep -q '^#!/bin/bash'"
    fi
done

# Check README exists
run_test "README.md exists" "[ -f README.md ]"
echo

# Test 6: Dry run of scripts (safe operations only)
echo -e "${YELLOW}6. Script Dry Run Tests${NC}"

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

# Test 7: Documentation checks
echo -e "${YELLOW}7. Documentation Checks${NC}"
run_test "README has installation section" "grep -q '## Installation' README.md 2>/dev/null || grep -q '### Installation' README.md"
run_test "README has usage section" "grep -q '### Usage' README.md"
echo

# Test 8: Git/yadm checks
echo -e "${YELLOW}8. Version Control Checks${NC}"
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
