#!/bin/bash

# Daily Maintenance Control Script
# Use this to manage your automated daily maintenance

# Shared colors, paths, and helpers
# shellcheck source=daily-maintenance-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/daily-maintenance-lib.sh"

case "$1" in
    status)
        echo "Checking daily maintenance status..."
        if dm_loaded; then
            echo "✓ Daily maintenance is ACTIVE"
            launchctl list | grep "com.daily-maintenance"
        else
            echo "✗ Daily maintenance is NOT ACTIVE"
        fi
        ;;

    start|enable)
        echo "Starting daily maintenance..."
        if dm_loaded; then
            echo "✓ Daily maintenance already running"
        elif dm_load; then
            echo "✓ Daily maintenance started"
        else
            echo "✗ Failed to start daily maintenance"
            exit 1
        fi
        ;;

    stop|disable)
        echo "Stopping daily maintenance..."
        dm_unload
        echo "✓ Daily maintenance stopped"
        ;;

    restart)
        echo "Restarting daily maintenance..."
        dm_unload 2>/dev/null
        dm_load
        echo "✓ Daily maintenance restarted"
        ;;

    run)
        echo "Running maintenance manually..."
        bash "$MAINTENANCE_SCRIPT"
        ;;
    
    logs)
        echo "=== Recent maintenance logs ==="
        if [ -f "$LOG_PATH" ]; then
            tail -n 50 "$LOG_PATH"
        else
            echo "No logs found yet"
        fi
        if [ -f "$ERROR_LOG_PATH" ] && [ -s "$ERROR_LOG_PATH" ]; then
            echo ""
            echo "=== Recent error logs ==="
            tail -n 20 "$ERROR_LOG_PATH"
        fi
        ;;
    
    edit)
        ${EDITOR:-nano} "$MAINTENANCE_SCRIPT"
        ;;
    
    *)
        echo "Daily Maintenance Control"
        echo ""
        echo "Usage: $0 {status|start|stop|restart|run|logs|edit}"
        echo ""
        echo "Commands:"
        echo "  status   - Check if automation is active"
        echo "  start    - Enable daily automation"
        echo "  stop     - Disable daily automation"
        echo "  restart  - Restart the automation"
        echo "  run      - Run maintenance manually now"
        echo "  logs     - View recent logs"
        echo "  edit     - Edit the maintenance script"
        echo ""
        echo "Schedule: Daily at 9:00 AM"
        echo "Script: $MAINTENANCE_SCRIPT"
        ;;
esac
