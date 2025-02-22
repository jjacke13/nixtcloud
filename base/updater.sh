#!/bin/bash

REPO_URL="https://github.com/jjacke13/nixtcloud.git"
REPO_DIR="/home/admin/nixtcloud"
BRANCH="test"
DEVICE=$(cat /etc/nixos/device.txt)

# Check if the repo exists
if [ -d "$REPO_DIR/.git" ]; then
  echo "Repository exists. Checking for updates..."
  cd "$REPO_DIR" || exit 1

  # Fetch remote changes
  git fetch origin "$BRANCH"

  # Check if there are changes
  if ! git diff --quiet HEAD origin/"$BRANCH"; then
    echo "Changes detected, pulling latest version..."
    git pull origin "$BRANCH"
    
    # Run the command only if there were changes
    echo "Updating..."
    nixos-rebuild switch --flake .#"$DEVICE"
    
  else
    echo "No changes detected."
  fi
else
  echo "Repository not found. Cloning..."
  git clone --branch "$BRANCH" --single-branch "$REPO_URL" "$REPO_DIR"
  cd "$REPO_DIR" || exit 1

fi