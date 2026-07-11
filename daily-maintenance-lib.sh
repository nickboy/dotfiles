#!/bin/bash

# Shared library for the daily-maintenance scripts
# (install-daily-maintenance.sh, uninstall-daily-maintenance.sh,
#  daily-maintenance-control.sh). Source it, don't execute it:
#   source "$(dirname "${BASH_SOURCE[0]}")/daily-maintenance-lib.sh"

# Colors for output
# shellcheck disable=SC2034  # consumers use different subsets of the palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Shared paths
LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"
# yadm-native template ('yadm alt' regenerates the real plist from it on
# every clone/pull; {{env.HOME}} expands to the actual home directory)
PLIST_TEMPLATE="$LAUNCHAGENT_DIR/com.daily-maintenance.plist##template"
PLIST_FILE="$LAUNCHAGENT_DIR/com.daily-maintenance.plist"
MAINTENANCE_SCRIPT="$HOME/daily-maintenance.sh"
CONTROL_SCRIPT="$HOME/daily-maintenance-control.sh"
LOG_DIR="$HOME/Library/Logs"
LOG_PATH="$LOG_DIR/daily-maintenance.log"
ERROR_LOG_PATH="$LOG_DIR/daily-maintenance-error.log"

# Print ✓/✗ for an exit code. Under 'set -e' call it only with a literal
# status you already own the control flow for — 'cmd; print_status $?'
# aborts the script before the ✗ branch can ever print.
print_status() {
    if [ "$1" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ask a y/n question. When stdin is not a TTY (piped yadm bootstrap, CI),
# silently take the default instead of aborting on read EOF — a bare
# 'read -p' under 'set -e' kills the whole installer in that case.
# Usage: if prompt_yes_no "Continue?" n; then ... fi
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local reply
    if [ ! -t 0 ]; then
        echo "$prompt (y/n) -> non-interactive, defaulting to '$default'"
        [ "$default" = "y" ]
        return
    fi
    read -p "$prompt (y/n) " -n 1 -r reply
    echo
    [[ $reply =~ ^[Yy]$ ]]
}

# Modern launchctl (bootstrap/bootout/enable) instead of load/unload.
# Evidence, 2026-07-10: the agent sat "disabled" in launchd's override DB;
# plain 'launchctl load' failed with "Load failed: 5" yet still EXITED 0,
# so the old '|| launchctl load -w' fallback never fired and the schedule
# was silently dead since 2026-07-03. bootstrap/bootout return real exit
# codes, and dm_load clears the disabled override first.
DM_LABEL="com.daily-maintenance"
DM_DOMAIN="gui/$(id -u)"

dm_loaded() {
    launchctl print "$DM_DOMAIN/$DM_LABEL" >/dev/null 2>&1
}

dm_load() {
    # Clear a persisted disable flag (e.g. from an old 'unload -w'),
    # then bootstrap the job into the GUI domain.
    launchctl enable "$DM_DOMAIN/$DM_LABEL" 2>/dev/null || true
    launchctl bootstrap "$DM_DOMAIN" "$PLIST_FILE"
}

dm_unload() {
    launchctl bootout "$DM_DOMAIN/$DM_LABEL"
}
