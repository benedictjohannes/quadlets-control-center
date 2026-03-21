#!/usr/bin/env bash
# caddy-https-warmup.sh: Warm up TLS certificates (ACME and internal)
# Reads Caddyfiles and issues HEAD requests to trigger certificate generation/renewal

# Determine base directory relative to the script location
BASE_DIR="${BASH_SOURCE[0]%/*}/.."
# Default to sites/ inside BASE_DIR, but allow override
SITES_DIR="${1:-$BASE_DIR/sites}"
MAIN_CADDYFILE="$BASE_DIR/Caddyfile"

LOG_PREFIX="[caddy-warmup]"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $*"; }

# Check for curl
if ! command -v curl &>/dev/null; then
    log "ERROR: curl is required but not installed"
    exit 1
fi

log "Starting HTTPS warmup..."

# Track statistics
total=0
success=0
failed=0

# Extract unique hostnames
# 1. Finds anything ending in .localhost or a standard TLD
# 2. excludes omega-bench01.io (which is used for the wildcard/tunnel wrapper)
# 4. 'grep -o' ensures we get every domain even if multiple are on one line
HOSTS=$(grep -rhE "[a-zA-Z0-9._-]+\.(localhost|[a-z]{2,})" "$SITES_DIR" "$MAIN_CADDYFILE" 2>/dev/null | \
        grep -oE "[a-zA-Z0-9._-]+\.(localhost|[a-z]{2,})" | \
        grep -vE "omega-bench01\.io" | \
        sort -u)

if [[ -z "$HOSTS" ]]; then
    log "No domains found to warm up."
    exit 0
fi

log "Warming up $(echo "$HOSTS" | wc -l) hosts..."

for host in $HOSTS; do
    ((total++)) || true
    url="https://$host/"
    
    # -k: Insecure, allows warming up expired/invalid certs (the goal is to trigger renewal)
    # -I: HEAD request
    # -s: Silent
    # -o /dev/null: discard output
    # -w "%{http_code}": output HTTP status code
    # -m 10: 10-second timeout
    http_code=$(curl -s -k -I -o /dev/null -w "%{http_code}" -m 10 "$url" 2>/dev/null || echo "000")
    
    if [[ "$http_code" =~ ^[23] ]]; then
        log "  ✓ $host (HTTP $http_code)"
        ((success++)) || true
    else
        log "  ✗ $host (Failed/HTTP $http_code)"
        ((failed++)) || true
    fi
done

log "Warmup complete: $total total, $success successful, $failed failed"

# Exit with error if any requests failed
if [[ $failed -gt 0 ]]; then
    exit 1
fi
