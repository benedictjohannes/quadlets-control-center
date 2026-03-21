#!/usr/bin/env bash

# quadlets-status.sh: PM2-style status dashboard for Quadlet services
# Author: Omega ControlCentre

CONTAINER_DIR="/home/omega/.config/containers/systemd"

# Get names from .container files in the systemd path
mapfile -t SERVICES < <(ls "$CONTAINER_DIR"/*.container 2>/dev/null | xargs -n1 basename | sed 's/\.container//')

if [ ${#SERVICES[@]} -eq 0 ]; then
    echo "No managed services found in $CONTAINER_DIR"
    exit 0
fi

# Fetch all podman stats at once
TEMP_STATS=$(podman stats --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}" "${SERVICES[@]}" 2>/dev/null)

# Print Header
printf "\033[1m%-25s %-10s %-10s %-10s %-12s %-20s\033[0m\n" "SERVICE" "STATUS" "RESTARTS" "CPU %" "MEM" "SINCE"
printf "%-25s %-10s %-10s %-10s %-12s %-20s\n" "-------" "------" "--------" "-----" "---" "------"

for SVC in "${SERVICES[@]}"; do
    PROPS=$(systemctl --user show "$SVC" --property=ActiveState,ActiveEnterTimestamp,NRestarts 2>/dev/null)
    ACTIVE_STATE=$(echo "$PROPS" | grep "^ActiveState=" | cut -d'=' -f2)
    RESTARTS=$(echo "$PROPS" | grep "^NRestarts=" | cut -d'=' -f2)
    
    SINCE="-"
    if [ "$ACTIVE_STATE" == "active" ]; then
        SINCE=$(echo "$PROPS" | grep "^ActiveEnterTimestamp=" | cut -d'=' -f2)
        SINCE=$(echo "$SINCE" | sed 's/ [A-Z]\{3\}$//') 
    fi

    CPU="-"
    MEM="-"
    STATS_LINE=$(echo "$TEMP_STATS" | grep "^$SVC|")
    if [ -n "$STATS_LINE" ]; then
        CPU=$(echo "$STATS_LINE" | cut -d'|' -f2)
        MEM=$(echo "$STATS_LINE" | cut -d'|' -f3 | cut -d' ' -f1)
    fi

    case "$ACTIVE_STATE" in
        active)  STATUS_COLOR="\033[0;32m" ;; # Green
        failed)  STATUS_COLOR="\033[0;31m" ;; # Red
        *)       STATUS_COLOR="\033[0;33m" ;; # Yellow
    esac
    NC="\033[0m"

    printf "%-25s ${STATUS_COLOR}%-10s${NC} %-10s %-10s %-12s %-20s\n" "$SVC" "$ACTIVE_STATE" "$RESTARTS" "$CPU" "$MEM" "$SINCE"
done
