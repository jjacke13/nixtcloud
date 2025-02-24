#!/bin/bash
set -eo pipefail

if [ ! -f /etc/nixos/version.txt ]; then
  
  local_version=$(curl https://api.github.com/repos/jjacke13/nixtcloud/commits/test | jq -r '[.sha, .commit.author.date]')
  echo "$local_version" > /etc/nixos/version.txt
  echo "created"
  
else

  # Retrieve latest commit hash
  new_version=$(curl https://api.github.com/repos/jjacke13/nixtcloud/commits/test | jq -r '[.sha, .commit.author.date]')
  echo "$new_version" > /tmp/version.txt
  # Retrieve stored commit hash
  local_version="/etc/nixos/version.txt"

  # Compare hashes
  if ! cmp -s /tmp/version.txt $local_version; then
    echo "Changes detected!"
    echo "$new_version" > /etc/nixos/version.txt
    DEVICE="$(cat /etc/nixos/device.txt)"
    nixos-rebuild switch --flake github:jjacke13/nixtcloud/test#"$DEVICE"
  else
    echo "No changes detected." #>> update_log.txt
  fi
  
fi
#echo "Check completed at $(date)" >> update_log.txt