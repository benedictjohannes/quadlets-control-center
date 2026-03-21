#!/usr/bin/env bash

# caddy-sync-volumes.sh: Extract /srv paths from Caddyfiles and update Podman/Quadlet container

USER_HOME="/home/omega"
CONTROL_CENTRE="$USER_HOME/ControlCentre"
PROJECTS_ROOT="$USER_HOME/Projects"
CONTAINER_FILE="$CONTROL_CENTRE/containers/caddy.container"

DRY_RUN=false
RESTART=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --restart) RESTART=true ;;
    esac
    shift
done

# 1. Extract all /srv/... paths from Caddyfiles
PATHS=$(grep -rhE "/srv/[^[:space:]}\"']+" "$CONTROL_CENTRE/sites" "$CONTROL_CENTRE/Caddyfile" 2>/dev/null | \
        sed -E "s/.*(\/srv\/[^[:space:]}\"']+).*/\1/" | \
        grep -v "^/srv/caddy" | \
        sort -u)

# 2. Build the NEW_VOLUMES block
NEW_BLOCK="# BEGIN_VOLUMES\n"
for container_path in $PATHS; do
    # Strip /srv/ to get relative path
    # We assume /srv/alpha/web maps to /home/omega/Projects/alpha/web
    rel_path=${container_path#/srv/}
    host_path="$PROJECTS_ROOT/$rel_path"

    if [ -e "$host_path" ]; then
        NEW_BLOCK+="Volume=$host_path:$container_path:ro,Z\n"
    else
        echo "Warning: Skipped $container_path because $host_path does not exist on host." >&2
    fi
done
NEW_BLOCK+="# END_VOLUMES"

# 3. Update the container file
if [ "$DRY_RUN" = true ]; then
    echo "--- DRY RUN (Proposed Volume Block) ---"
    echo -e "$NEW_BLOCK"
else
    if [ ! -f "$CONTAINER_FILE" ]; then
        echo "Error: $CONTAINER_FILE not found." >&2
        exit 1
    fi

    echo "Updating $CONTAINER_FILE..."
    ESCAPED_BLOCK=$(echo -e "$NEW_BLOCK" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\//\\\//g')
    
    TMP_FILE=$(mktemp)
    sed "/# BEGIN_VOLUMES/,/# END_VOLUMES/c $ESCAPED_BLOCK" "$CONTAINER_FILE" > "$TMP_FILE"
    mv "$TMP_FILE" "$CONTAINER_FILE"
    
    echo "Successfully updated $CONTAINER_FILE"

    if [ "$RESTART" = true ]; then
        systemctl --user daemon-reload
        systemctl --user restart caddy.service
        echo "Caddy restarted."
    fi
fi
