#!/bin/bash

# Daily Maintenance Installation Script
# This script sets up the automated daily maintenance system

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$HOME"
LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs"

# Files to check/install
MAINTENANCE_SCRIPT="$SCRIPT_DIR/daily-maintenance.sh"
CONTROL_SCRIPT="$SCRIPT_DIR/daily-maintenance-control.sh"
PLIST_TEMPLATE="$LAUNCHAGENT_DIR/com.daily-maintenance.plist.template"
PLIST_FILE="$LAUNCHAGENT_DIR/com.daily-maintenance.plist"
SUDOERS_TEMPLATE="$SCRIPT_DIR/daily-maintenance-sudoers"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Daily Maintenance Automation Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

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
    sed "s|{{HOME}}|$HOME|g" "$PLIST_TEMPLATE" > "$PLIST_FILE"
    print_status $? "Generated plist file"
elif [ -f "$PLIST_FILE" ]; then
    print_status 0 "LaunchAgent plist found"
else
    print_status 1 "Neither plist template nor plist file found"
    echo "  Please ensure you've cloned the dotfiles repository with yadm"
    exit 1
fi

echo

# Make scripts executable
echo -e "${YELLOW}Setting up scripts...${NC}"

chmod +x "$MAINTENANCE_SCRIPT"
print_status $? "Made daily-maintenance.sh executable"

chmod +x "$CONTROL_SCRIPT"
print_status $? "Made daily-maintenance-control.sh executable"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
print_status $? "Created log directory"

echo

# Check if automation is already running
echo -e "${YELLOW}Checking existing installation...${NC}"

if launchctl list | grep -q "com.nickboy.daily-maintenance"; then
    echo -e "${YELLOW}⚠${NC} Daily maintenance automation is already installed and running"
    read -p "Do you want to reload it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        launchctl unload "$PLIST_FILE" 2>/dev/null
        launchctl load "$PLIST_FILE"
        print_status $? "Reloaded automation"
    fi
else
    # Load the LaunchAgent
    echo -e "${YELLOW}Installing automation...${NC}"
    launchctl load "$PLIST_FILE"
    print_status $? "Loaded LaunchAgent"
fi

echo

# Test the script
echo -e "${YELLOW}Testing the maintenance script...${NC}"
read -p "Do you want to run a test now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Running test...${NC}"
    bash "$MAINTENANCE_SCRIPT"
    TEST_EXIT_CODE=$?
    echo
    print_status $TEST_EXIT_CODE "Test completed"
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

# Check for sudo requirements
if [ -f "$SUDOERS_TEMPLATE" ]; then
    echo -e "${YELLOW}Note:${NC} If any commands require sudo access, see:"
    echo "  $SUDOERS_TEMPLATE"
    echo "  for configuration instructions"
    echo
fi

echo -e "${BLUE}To change the schedule, edit:${NC}"
echo "  $PLIST_FILE"
echo "  Then run: ~/daily-maintenance-control.sh restart"
echo

exit 0
