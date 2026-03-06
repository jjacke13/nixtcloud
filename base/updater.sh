#!/bin/bash
set -eo pipefail

LOG_FILE="/etc/nixos/updates.log"
VERSION_FILE="/etc/nixos/version.txt"
RELEASE_URL="https://api.github.com/repos/jjacke13/nixtcloud/releases"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; }

if ! curl -sf --max-time 10 "https://api.github.com" >/dev/null; then
    log "No internet connectivity - skipping update check"
    exit 0
fi

if ! release_data=$(curl -sf --max-time 30 "$RELEASE_URL" | jq -r '[.[] | select(.prerelease == true)] | .[0]'); then
    log "Failed to fetch releases - skipping update"
    exit 0
fi

TAG=$(echo "$release_data" | jq -r '.tag_name')

if [ -z "$TAG" ] || [ "$TAG" = "null" ]; then
    log "No pre-release found - skipping update"
    exit 0
fi

if [ -f "$VERSION_FILE" ] && [ "$TAG" = "$(cat "$VERSION_FILE")" ]; then
    log "No new release (current: $TAG)"
    exit 0
fi

DEVICE=$(cat /etc/nixos/device.txt)
DOWNLOAD_URL="https://github.com/jjacke13/nixtcloud/releases/download/$TAG/$DEVICE-toplevel.nar.gz"
NAR_FILE="/tmp/$DEVICE-toplevel.nar.gz"

log "New release $TAG found - downloading NAR for $DEVICE"

if ! curl -sfL --max-time 300 -o "$NAR_FILE" "$DOWNLOAD_URL"; then
    log "Failed to download NAR"
    exit 1
fi

log "Importing NAR..."
if ! TOPLEVEL=$(gunzip -c "$NAR_FILE" | nix-store --import | tail -1); then
    log "Failed to import NAR"
    rm -f "$NAR_FILE"
    exit 1
fi

log "Activating with switch-to-configuration test..."
if ! "$TOPLEVEL/bin/switch-to-configuration" test 2>&1 | tee -a "$LOG_FILE"; then
    log "switch-to-configuration test failed"
    rm -f "$NAR_FILE"
    exit 1
fi

log "Setting boot configuration..."
if ! "$TOPLEVEL/bin/switch-to-configuration" boot 2>&1 | tee -a "$LOG_FILE"; then
    log "switch-to-configuration boot failed"
    rm -f "$NAR_FILE"
    exit 1
fi

echo "$TAG" > "$VERSION_FILE"
rm -f "$NAR_FILE"
log "Update to $TAG completed - rebooting in 30s"
sleep 30 && reboot
