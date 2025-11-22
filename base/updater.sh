#!/bin/bash
set -eo pipefail

LOG_FILE="/etc/nixos/updates.log"
VERSION_FILE="/etc/nixos/version.txt" 
RELEASES_URL="https://api.github.com/repos/jjacke13/nixtcloud/releases/latest"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; }

# Quick connectivity check
if ! curl -sf --max-time 10 "https://api.github.com" >/dev/null; then
    log "No internet connectivity - skipping update check"
    exit 0
fi

# Get latest release from GitHub
if ! latest=$(curl -sf --max-time 30 "$RELEASES_URL" | jq -r '.tag_name'); then
    log "Failed to fetch latest release - skipping update"
    exit 0
fi

# Compare with stored version
if [ -f "$VERSION_FILE" ] && [ "$latest" = "$(cat "$VERSION_FILE")" ]; then
    log "No changes detected"
    exit 0
fi

log "Update available: $latest - rebuilding"
DEVICE=$(cat /etc/nixos/device.txt)
if nixos-rebuild boot --flake "github:jjacke13/nixtcloud/$latest#$DEVICE" 2>&1 | tee -a "$LOG_FILE"; then
    echo "$latest" > "$VERSION_FILE"
    log "Update completed: $latest - rebooting in 30s"
    sleep 30 && reboot
else
    log "Build failed"
fi