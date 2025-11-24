#!/bin/bash

# Daily Maintenance Script
# This script runs various update and backup commands

# Track last run time
LAST_RUN_FILE="$HOME/.daily-maintenance-last-run"
CURRENT_DATE=$(date +%Y-%m-%d)

# Check if we're running from launchd with --auto flag
if [[ "$1" == "--auto" ]]; then
    # Check if already ran today
    if [ -f "$LAST_RUN_FILE" ]; then
        LAST_RUN=$(cat "$LAST_RUN_FILE")
        if [ "$LAST_RUN" == "$CURRENT_DATE" ]; then
            echo "Daily maintenance already completed today ($CURRENT_DATE)"
            exit 0
        fi
    fi
fi

echo "========================================="
echo "Starting daily maintenance: $(date)"
echo "========================================="

# Set up PATH to include homebrew
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Function to run command and check status
run_command() {
    local description="$1"
    shift
    local command="$*"
    
    echo ""
    echo "----------------------------------------"
    echo "Task: $description"
    echo "Command: $command"
    echo -n "Status: "
    
    # Run the command
    if $command; then
        echo "✓ SUCCESS"
        return 0
    else
        local exit_code=$?
        echo "✗ FAILED (exit code: $exit_code)"
        return $exit_code
    fi
}

# Keep track of failures
FAILED_COMMANDS=()

# Run your daily maintenance commands
if ! run_command "Homebrew formula upgrade" brew upgrade; then
    FAILED_COMMANDS+=("brew upgrade")
fi

if ! run_command "Homebrew cask upgrade (greedy)" brew upgrade --cask --greedy; then
    FAILED_COMMANDS+=("brew upgrade --cask --greedy")
fi

# For zinit, we need to ensure it's available
ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
if [ -f "$ZINIT_HOME/zinit.zsh" ]; then
    echo ""
    echo "----------------------------------------"
    echo "Task: Zinit update"
    echo "Command: zinit update --all --quiet"
    echo -n "Status: "

    # Run zinit update by sourcing directly (avoid zsh -i which can hang)
    if zsh -c "source '$ZINIT_HOME/zinit.zsh' && zinit update --all --quiet" >/dev/null 2>&1; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("zinit update")
    fi
else
    echo "Warning: zinit not found, skipping zinit update"
fi

if ! run_command "Bob (Neovim version manager) update" /opt/homebrew/bin/bob update nightly; then
    FAILED_COMMANDS+=("bob update nightly")
fi

# Update LazyVim plugins
if command -v nvim >/dev/null 2>&1; then
    echo ""
    echo "----------------------------------------"
    echo "Task: LazyVim plugin updates"
    echo "Command: nvim --headless '+Lazy! sync' +qa"
    echo -n "Status: "
    
    # Run Neovim in headless mode to update LazyVim plugins
    # --headless: Run without UI
    # '+Lazy! sync': Run Lazy sync command (! means no prompts)
    # +qa: Quit all windows
    if nvim --headless "+Lazy! sync" +qa 2>/dev/null; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("LazyVim update")
    fi
else
    echo "Warning: Neovim not found, skipping LazyVim updates"
fi

# Clean up old Homebrew versions and cache
if command -v brew >/dev/null 2>&1; then
    echo ""
    echo "----------------------------------------"
    echo "Task: Homebrew cleanup"
    echo "Command: brew cleanup --prune=all"
    echo -n "Status: "
    
    # Run cleanup to remove old versions and clear cache
    # --prune=all removes all cache entries
    if brew cleanup --prune=all 2>/dev/null; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("brew cleanup")
    fi
fi

echo ""
echo "========================================="
if [ ${#FAILED_COMMANDS[@]} -eq 0 ]; then
    echo "✓ Daily maintenance completed successfully!"
    # Record successful run
    echo "$CURRENT_DATE" > "$LAST_RUN_FILE"
else
    echo "⚠ Daily maintenance completed with errors:"
    for cmd in "${FAILED_COMMANDS[@]}"; do
        echo "  - $cmd failed"
    done
    # Still record the run even with errors
    echo "$CURRENT_DATE" > "$LAST_RUN_FILE"
fi
echo "Time: $(date)"
echo "=========================================="
