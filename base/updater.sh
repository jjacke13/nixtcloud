#!/bin/bash
set -eo pipefail
LOG_FILE="/etc/nixos/updates.log"

if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

if [ ! -f /etc/nixos/version.txt ]; then
  
  local_version=$(curl https://api.github.com/repos/jjacke13/nixtcloud/commits/main | jq -r '[.sha, .commit.author.date]')
  echo "$local_version" > /etc/nixos/version.txt
  echo "created"
  
else

  # Retrieve latest commit hash
  new_version=$(curl https://api.github.com/repos/jjacke13/nixtcloud/commits/main | jq -r '[.sha, .commit.author.date]')
  echo "$new_version" > /tmp/version.txt
  # Retrieve stored commit hash
  local_version="/etc/nixos/version.txt"

  # Compare hashes
  if ! cmp -s /tmp/version.txt $local_version; then
    echo "Changes detected!"
    echo "$new_version" > /etc/nixos/version.txt
    DEVICE="$(cat /etc/nixos/device.txt)"
    log "Updating..."
    nixos-rebuild switch --flake github:jjacke13/nixtcloud/main#"$DEVICE" 2>&1 | tee -a "$LOG_FILE"
    if [ $? -ne 0 ]; then
            log "Error: Failed to rebuild NixOS configuration."
            exit 1
    fi
    log "Update completed successfully."
  
  else
    log "No changes detected." 
  fi
  
fi
log "Check completed at $(date)"