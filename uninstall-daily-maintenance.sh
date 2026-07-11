#!/bin/bash

# Daily Maintenance Uninstallation Script
# This script removes the automated daily maintenance system

# Shared colors, paths, and helpers
# shellcheck source=daily-maintenance-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/daily-maintenance-lib.sh"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Daily Maintenance Automation Uninstaller${NC}"
echo -e "${BLUE}========================================${NC}"
echo

echo -e "${YELLOW}This will disable the daily maintenance automation.${NC}"
echo "The script files will remain in your dotfiles but won't run automatically."
echo

if ! prompt_yes_no "Do you want to continue?" n; then
    echo "Uninstallation cancelled."
    exit 0
fi
echo

# Unload the LaunchAgent if it's running
if dm_loaded; then
    echo -e "${YELLOW}Stopping automation...${NC}"
    if dm_unload; then
        echo -e "${GREEN}✓${NC} Automation stopped"
    else
        echo -e "${RED}✗${NC} Failed to stop automation"
    fi
else
    echo -e "${YELLOW}⚠${NC} Automation was not running"
fi

echo

# Ask about log files
if prompt_yes_no "Do you want to remove log files?" n; then
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
echo "  • ~/Library/LaunchAgents/com.daily-maintenance.plist"
echo
echo "To reinstall, run:"
echo -e "  ${GREEN}bash ~/install-daily-maintenance.sh${NC}"
echo
echo "To manually run maintenance:"
echo -e "  ${GREEN}bash ~/daily-maintenance.sh${NC}"
echo

exit 0
