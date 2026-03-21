#!/usr/bin/env bash

# qctl.sh: CLI tool to manage Quadlets
# Central management for services Quadlet ran services.

CONTAINER_DIR="/home/omega/.config/containers/systemd"

usage() {
    echo "Usage: qctl [command] [name] [options]"
    echo ""
    echo "Monitoring Commands:"
    echo "  status                  Show status of all quadlets (default)"
    echo "  logs <name> [args...]   Tail logs (passes [args] to journalctl)"
    echo ""
    echo "Lifecycle management:"
    echo "  start <name>            Start a quadlet service"
    echo "  stop <name>             Stop a quadlet service"
    echo "  restart <name>          Restart a quadlet service"
    echo ""
    echo "Enable/Disable:"
    echo "  enable <name> [--now]   Enable quadlet (uncomment WantedBy)"
    echo "  disable <name> [--now]  Disable quadlet (comment out WantedBy)"
    echo "These commands also run systemctl --user daemon-reload immediately"
    echo "  --now: start/stop the service immediately"
    echo ""
    echo "  help                    Show this help"
}

show_status() {
    # Get names from .container files
    mapfile -t SERVICES < <(ls "$CONTAINER_DIR"/*.container 2>/dev/null | xargs -n1 basename | sed 's/\.container//')

    if [ ${#SERVICES[@]} -eq 0 ]; then
        echo "No managed services found in $CONTAINER_DIR"
        exit 0
    fi

    # Fetch all podman stats at once for performance
    TEMP_STATS=$(podman stats --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}" "${SERVICES[@]}" 2>/dev/null)

    # Print Header
    printf "\033[1m%-25s %-10s %-10s %-10s %-10s %-12s %-20s\033[0m\n" "SERVICE" "STATUS" "STARTUP" "RESTARTS" "CPU %" "MEM" "SINCE"
    printf "%-25s %-10s %-10s %-10s %-10s %-12s %-20s\n" "-------" "------" "-------" "--------" "-----" "---" "------"

    for SVC in "${SERVICES[@]}"; do
        # Get Systemd Info
        PROPS=$(systemctl --user show "$SVC" --property=ActiveState,ActiveEnterTimestamp,NRestarts 2>/dev/null)
        ACTIVE_STATE=$(echo "$PROPS" | grep "^ActiveState=" | cut -d'=' -f2)
        RESTARTS=$(echo "$PROPS" | grep "^NRestarts=" | cut -d'=' -f2)
        
        # Check enabled state from file
        FILE="$CONTAINER_DIR/$SVC.container"
        STARTUP="No"
        if [ -f "$FILE" ]; then
            if grep -q "^WantedBy=" "$FILE"; then
                STARTUP="Yes"
            fi
        fi

        # Get Uptime / Since
        SINCE="-"
        if [ "$ACTIVE_STATE" == "active" ]; then
            SINCE=$(echo "$PROPS" | grep "^ActiveEnterTimestamp=" | cut -d'=' -f2)
            SINCE=$(echo "$SINCE" | sed 's/ [A-Z]\{3\}$//') # Remove timezone abbreviation like WIB/GMT
        fi

        # Extract Stats from our pre-fetched block
        CPU="-"
        MEM="-"
        STATS_LINE=$(echo "$TEMP_STATS" | grep "^$SVC|")
        if [ -n "$STATS_LINE" ]; then
            CPU=$(echo "$STATS_LINE" | cut -d'|' -f2)
            MEM=$(echo "$STATS_LINE" | cut -d'|' -f3 | cut -d' ' -f1)
        fi

        # Colorize Status
        case "$ACTIVE_STATE" in
            active)  STATUS_COLOR="\033[0;32m" ;; # Green
            failed)  STATUS_COLOR="\033[0;31m" ;; # Red
            *)       STATUS_COLOR="\033[0;33m" ;; # Yellow
        esac
        
        STARTUP_COLOR="\033[0m"
        if [ "$STARTUP" == "Yes" ]; then
            STARTUP_COLOR="\033[0;36m" # Cyan
        fi

        NC="\033[0m" # No Color

        printf "%-25s ${STATUS_COLOR}%-10s${NC} ${STARTUP_COLOR}%-10s${NC} %-10s %-10s %-12s %-20s\n" "$SVC" "$ACTIVE_STATE" "$STARTUP" "$RESTARTS" "$CPU" "$MEM" "$SINCE"
    done
}

# Main CLI logic
CMD=${1:-status}
NAME=$2
NOW=false

if [[ "$2" == "--now" || "$3" == "--now" ]]; then
    NOW=true
fi

# Adjust for "qctl enable name --now" vs "qctl enable --now name"
if [[ "$NAME" == "--now" ]]; then
    NAME=$3
fi

case "$CMD" in
    status)
        show_status
        ;;
    start|stop|restart)
        if [ -z "$NAME" ]; then
            echo "Error: Name required for $CMD"
            exit 1
        fi
        echo "Executing: systemctl --user $CMD $NAME"
        systemctl --user "$CMD" "$NAME"
        ;;
    enable)
        if [ -z "$NAME" ]; then
            echo "Error: Name required for enable"
            exit 1
        fi
        FILE="$CONTAINER_DIR/$NAME.container"
        if [ ! -f "$FILE" ]; then
            echo "Error: Quadlet file $FILE not found."
            exit 1
        fi

        # Logic: If ANY WantedBy line is commented (# WantedBy=), uncomment them all.
        if grep -q "^# *WantedBy=" "$FILE"; then
            sed -i 's/^# *\(WantedBy=.*\)/\1/' "$FILE"
            echo "Enabled: $NAME (Uncommented all WantedBy lines)"
            systemctl --user daemon-reload
            if [ "$NOW" == "true" ]; then
                systemctl --user start "$NAME"
                echo "Started: $NAME"
            fi
        # If no lines were commented, but at least one exists uncommented
        elif grep -q "^WantedBy=" "$FILE"; then
            echo "Already enabled: $NAME"
        else
            echo "Error: No [Install] section or WantedBy= found in $FILE."
            exit 1
        fi
        ;;
    disable)
        if [ -z "$NAME" ]; then
            echo "Error: Name required for disable"
            exit 1
        fi
        FILE="$CONTAINER_DIR/$NAME.container"
        if [ ! -f "$FILE" ]; then
            echo "Error: Quadlet file $FILE not found."
            exit 1
        fi
        if grep -q "^WantedBy=" "$FILE"; then
            sed -i 's/^\(WantedBy=.*\)/# \1/' "$FILE"
            echo "Disabled: $NAME (Commented all WantedBy lines)"
            systemctl --user daemon-reload
            if [ "$NOW" == "true" ]; then
                systemctl --user stop "$NAME"
                echo "Stopped: $NAME"
            fi
        else
            echo "Already disabled or not configured: $NAME"
        fi
        ;;
    logs)
        if [ -z "$NAME" ]; then
            echo "Error: Name required for logs"
            exit 1
        fi
        
        # Build the argument list by pulling everything that wasn't CMD or NAME
        JOURNAL_ARGS=""
        for arg in "$@"; do
            if [[ "$arg" != "$CMD" && "$arg" != "$NAME" && "$arg" != "--now" ]]; then
                JOURNAL_ARGS="$JOURNAL_ARGS $arg"
            fi
        done

        if [ -z "$JOURNAL_ARGS" ]; then
            journalctl --user -u "$NAME" -f
        else
            journalctl --user -u "$NAME" $JOURNAL_ARGS
        fi
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $CMD"
        usage
        exit 1
        ;;
esac
