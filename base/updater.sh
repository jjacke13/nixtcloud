#!/bin/bash
set -eo pipefail

LOG_FILE="/etc/nixos/updates.log"
VERSION_FILE="/etc/nixos/version.txt" 
REPO_URL="https://api.github.com/repos/jjacke13/nixtcloud/commits/test"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; }

# Quick connectivity check
if ! curl -sf --max-time 10 "https://api.github.com" >/dev/null; then
    log "No internet connectivity - skipping update check"
    exit 0
fi

# Get latest version from GitHub
if ! latest=$(curl -sf --max-time 30 "$REPO_URL" | jq -r '[.sha, .commit.author.date]'); then
    log "Failed to fetch latest version - skipping update"
    exit 0
fi

# Compare with stored version
if [ -f "$VERSION_FILE" ] && [ "$latest" = "$(cat "$VERSION_FILE")" ]; then
    log "No changes detected"
    exit 0
fi

log "Update available: $(echo "$latest" | jq -r '.[0]' | cut -c1-8) - rebuilding"
DEVICE=$(cat /etc/nixos/device.txt)
if nixos-rebuild boot --flake "github:jjacke13/nixtcloud/test#$DEVICE" --accept-flake-config 2>&1 | tee -a "$LOG_FILE"; then
    echo "$latest" > "$VERSION_FILE"
    log "Update completed: $(echo "$latest" | jq -r '.[0]' | cut -c1-8) - rebooting in 30s"
    sleep 30 && reboot
else
    log "Build failed"
fi