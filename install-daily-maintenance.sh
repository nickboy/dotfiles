#!/bin/bash

# Daily Maintenance Installation Script
# This script sets up the automated daily maintenance system

set -e  # Exit on error

# Shared colors, paths, and helpers
# shellcheck source=daily-maintenance-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/daily-maintenance-lib.sh"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Daily Maintenance Automation Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for Homebrew
if command_exists brew; then
    print_status 0 "Homebrew is installed"
else
    print_status 1 "Homebrew is not installed"
    echo "  Please install Homebrew first: https://brew.sh/"
    exit 1
fi

# Check for required commands
REQUIRED_COMMANDS=("bob" "zsh")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if command_exists "$cmd"; then
        print_status 0 "$cmd is available"
    else
        echo -e "${YELLOW}⚠${NC} $cmd is not installed"
        echo "  You can install it with: brew install $cmd"
    fi
done

# Check for zinit
if [ -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ] || [ -f "$HOME/.zinit/bin/zinit.zsh" ]; then
    print_status 0 "zinit is installed"
else
    echo -e "${YELLOW}⚠${NC} zinit not found - zinit updates will be skipped"
fi

echo

# Check if files exist
echo -e "${YELLOW}Checking required files...${NC}"

if [ ! -f "$MAINTENANCE_SCRIPT" ]; then
    print_status 1 "daily-maintenance.sh not found"
    echo "  Please ensure you've cloned the dotfiles repository with yadm"
    exit 1
else
    print_status 0 "daily-maintenance.sh found"
fi

if [ ! -f "$CONTROL_SCRIPT" ]; then
    print_status 1 "daily-maintenance-control.sh not found"
    echo "  Please ensure you've cloned the dotfiles repository with yadm"
    exit 1
else
    print_status 0 "daily-maintenance-control.sh found"
fi

# Check for plist template or existing plist
if [ -f "$PLIST_TEMPLATE" ]; then
    print_status 0 "LaunchAgent plist template found"
    # Generate plist from template
    echo "Generating plist from template..."
    if sed "s|{{HOME}}|$HOME|g" "$PLIST_TEMPLATE" > "$PLIST_FILE"; then
        print_status 0 "Generated plist file"
    else
        print_status 1 "Failed to generate plist file" || true
        exit 1
    fi
elif [ -f "$PLIST_FILE" ]; then
    print_status 0 "LaunchAgent plist found"
else
    print_status 1 "Neither plist template nor plist file found"
    echo "  Please ensure you've cloned the dotfiles repository with yadm"
    exit 1
fi

echo

# Make scripts executable (set -e aborts on real failure, so reaching
# print_status means the command succeeded)
echo -e "${YELLOW}Setting up scripts...${NC}"

chmod +x "$MAINTENANCE_SCRIPT"
print_status 0 "Made daily-maintenance.sh executable"

chmod +x "$CONTROL_SCRIPT"
print_status 0 "Made daily-maintenance-control.sh executable"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
print_status 0 "Created log directory"

echo

# Check if automation is already running
echo -e "${YELLOW}Checking existing installation...${NC}"

if dm_loaded; then
    echo -e "${YELLOW}⚠${NC} Daily maintenance automation is already installed and running"
    # Non-interactive runs (yadm bootstrap) keep the existing agent as-is
    if prompt_yes_no "Do you want to reload it?" n; then
        dm_unload 2>/dev/null || true
        if dm_load; then
            print_status 0 "Reloaded automation"
        else
            print_status 1 "Failed to reload automation" || true
            exit 1
        fi
    fi
else
    # Load the LaunchAgent
    echo -e "${YELLOW}Installing automation...${NC}"
    if dm_load; then
        print_status 0 "Loaded LaunchAgent"
    else
        print_status 1 "Failed to load LaunchAgent" || true
        exit 1
    fi
fi

echo

# Test the script (skipped automatically when non-interactive)
echo -e "${YELLOW}Testing the maintenance script...${NC}"
if prompt_yes_no "Do you want to run a test now?" n; then
    echo -e "${BLUE}Running test...${NC}"
    if bash "$MAINTENANCE_SCRIPT"; then
        print_status 0 "Test completed"
    else
        print_status 1 "Test completed with errors (see output above)" || true
    fi
fi

echo

# Show next steps
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}The automation is now active and will run daily at 9:00 AM${NC}"
echo
echo "You can control it using:"
echo -e "  ${GREEN}~/daily-maintenance-control.sh status${NC}  - Check status"
echo -e "  ${GREEN}~/daily-maintenance-control.sh run${NC}     - Run manually"
echo -e "  ${GREEN}~/daily-maintenance-control.sh logs${NC}    - View logs"
echo -e "  ${GREEN}~/daily-maintenance-control.sh stop${NC}    - Disable automation"
echo
echo "Logs are saved to:"
echo "  • $LOG_DIR/daily-maintenance.log"
echo "  • $LOG_DIR/daily-maintenance-error.log"
echo

echo -e "${BLUE}To change the schedule, edit:${NC}"
echo "  $PLIST_FILE"
echo "  Then run: ~/daily-maintenance-control.sh restart"
echo

exit 0
