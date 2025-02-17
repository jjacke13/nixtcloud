#!/bin/bash
URL="https://raw.githubusercontent.com/jjacke13/nixtcloud/refs/heads/main/flake.lock"
LOCAL_FILE="/etc/nixos/flake.lock"
DEVICE="$(cat /etc/nixos/device)"
# Get the hash of the local file
LOCAL_HASH=$(sha256sum "$LOCAL_FILE" | awk '{print $1}')

# Get the hash of the online file
ONLINE_HASH=$(curl -sL "$URL" | sha256sum | awk '{print $1}')

# Compare the hashes
if [ "$LOCAL_HASH" == "$ONLINE_HASH" ]; then
    echo "The files are identical."
    echo "not updating"
    exit 0
else
    echo "updating"
    nixos-rebuild switch --flake github:jjacke13/nixtcloud#"$DEVICE"
fi