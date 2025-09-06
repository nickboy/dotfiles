#!/bin/bash

# Daily Maintenance Script
# This script runs various update and backup commands

echo "========================================="
echo "Starting daily maintenance: $(date)"
echo "========================================="

# Set up PATH to include homebrew
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Function to run command and check status
run_command() {
    local description="$1"
    shift
    local command="$@"
    
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
if [ -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ] || [ -f "$HOME/.zinit/bin/zinit.zsh" ]; then
    # Source zinit in a zsh subshell with proper quoting
    if ! run_command "Zinit update" zsh -c 'source ~/.zshrc && zinit update'; then
        FAILED_COMMANDS+=("zinit update")
    fi
else
    echo "Warning: zinit not found, skipping zinit update"
fi

if ! run_command "Bob (Neovim version manager) update" /opt/homebrew/bin/bob update; then
    FAILED_COMMANDS+=("bob update")
fi

echo ""
echo "========================================="
if [ ${#FAILED_COMMANDS[@]} -eq 0 ]; then
    echo "✓ Daily maintenance completed successfully!"
else
    echo "⚠ Daily maintenance completed with errors:"
    for cmd in "${FAILED_COMMANDS[@]}"; do
        echo "  - $cmd failed"
    done
fi
echo "Time: $(date)"
echo "=========================================="
