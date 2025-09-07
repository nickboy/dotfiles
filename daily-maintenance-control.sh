#!/bin/bash

# Daily Maintenance Control Script
# Use this to manage your automated daily maintenance

PLIST_PATH="$HOME/Library/LaunchAgents/com.daily-maintenance.plist"
SCRIPT_PATH="$HOME/daily-maintenance.sh"
LOG_PATH="$HOME/Library/Logs/daily-maintenance.log"
ERROR_LOG_PATH="$HOME/Library/Logs/daily-maintenance-error.log"

case "$1" in
    status)
        echo "Checking daily maintenance status..."
        if launchctl list | grep -q "com.nickboy.daily-maintenance"; then
            echo "✓ Daily maintenance is ACTIVE"
            launchctl list | grep "com.nickboy.daily-maintenance"
        else
            echo "✗ Daily maintenance is NOT ACTIVE"
        fi
        ;;
    
    start|enable)
        echo "Starting daily maintenance..."
        launchctl load "$PLIST_PATH" 2>/dev/null || launchctl load -w "$PLIST_PATH"
        echo "✓ Daily maintenance started"
        ;;
    
    stop|disable)
        echo "Stopping daily maintenance..."
        launchctl unload "$PLIST_PATH"
        echo "✓ Daily maintenance stopped"
        ;;
    
    restart)
        echo "Restarting daily maintenance..."
        launchctl unload "$PLIST_PATH" 2>/dev/null
        launchctl load "$PLIST_PATH"
        echo "✓ Daily maintenance restarted"
        ;;
    
    run)
        echo "Running maintenance manually..."
        bash "$SCRIPT_PATH"
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
        ${EDITOR:-nano} "$SCRIPT_PATH"
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
        echo "Script: $SCRIPT_PATH"
        ;;
esac
