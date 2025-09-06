#!/bin/bash

# Daily Maintenance Uninstallation Script
# This script removes the automated daily maintenance system

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLIST_FILE="$HOME/Library/LaunchAgents/com.nickboy.daily-maintenance.plist"
LOG_DIR="$HOME/Library/Logs"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Daily Maintenance Automation Uninstaller${NC}"
echo -e "${BLUE}========================================${NC}"
echo

echo -e "${YELLOW}This will disable the daily maintenance automation.${NC}"
echo "The script files will remain in your dotfiles but won't run automatically."
echo
read -p "Do you want to continue? (y/n) " -n 1 -r
echo
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Unload the LaunchAgent if it's running
if launchctl list | grep -q "com.nickboy.daily-maintenance"; then
    echo -e "${YELLOW}Stopping automation...${NC}"
    launchctl unload "$PLIST_FILE"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Automation stopped"
    else
        echo -e "${RED}✗${NC} Failed to stop automation"
    fi
else
    echo -e "${YELLOW}⚠${NC} Automation was not running"
fi

echo

# Ask about log files
read -p "Do you want to remove log files? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "$LOG_DIR/daily-maintenance.log" ]; then
        rm "$LOG_DIR/daily-maintenance.log"
        echo -e "${GREEN}✓${NC} Removed daily-maintenance.log"
    fi
    if [ -f "$LOG_DIR/daily-maintenance-error.log" ]; then
        rm "$LOG_DIR/daily-maintenance-error.log"
        echo -e "${GREEN}✓${NC} Removed daily-maintenance-error.log"
    fi
else
    echo "Log files preserved at:"
    echo "  • $LOG_DIR/daily-maintenance.log"
    echo "  • $LOG_DIR/daily-maintenance-error.log"
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Uninstallation Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo "The automation has been disabled."
echo
echo "Script files are still available at:"
echo "  • ~/daily-maintenance.sh"
echo "  • ~/daily-maintenance-control.sh"
echo "  • ~/Library/LaunchAgents/com.nickboy.daily-maintenance.plist"
echo
echo "To reinstall, run:"
echo -e "  ${GREEN}bash ~/install-daily-maintenance.sh${NC}"
echo
echo "To manually run maintenance:"
echo -e "  ${GREEN}bash ~/daily-maintenance.sh${NC}"
echo

exit 0
