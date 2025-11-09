#!/bin/bash
#
# USB Auto-Mounter for Nextcloud
# 
# This script automatically mounts USB storage devices and creates corresponding
# Nextcloud external storage entries. It also cleans up stale mounts and removes
# external storage entries when devices are unplugged.
#
# Triggered by:
# - systemd service that runs every 30 seconds

set -euo pipefail

# Configuration
readonly NEXTCLOUD_USER="nextcloud"     # User that owns Nextcloud files
readonly MOUNT_DIR="/mnt/usb"           # Base directory for USB mounts
readonly NEXTCLOUD_OCC="/run/current-system/sw/bin/nextcloud-occ"  # Nextcloud CLI tool

# Get nextcloud user IDs for proper file permissions
readonly uid=$(id -u "$NEXTCLOUD_USER")
readonly gid=$(id -g "$NEXTCLOUD_USER")

# Logging function with timestamps
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Clean up Nextcloud external storage entries for devices that are no longer mounted
# This handles both properly unmounted devices and stale mounts from unplugged devices
cleanup_unmounted_storage() {
    log "Cleaning up unmounted external storages..."
    
    for mount_point in "$MOUNT_DIR"/*; do
        [[ -d "$mount_point" ]] || continue
        
        local needs_cleanup=false
        
        if ! findmnt -M "$mount_point" &>/dev/null; then
            # Mount point is not mounted - normal case
            needs_cleanup=true
        else
            # Mount point appears mounted, but check if it's a stale mount
            # (device unplugged but mount entry still exists)
            local mount_source
            mount_source=$(findmnt -M "$mount_point" -o SOURCE --noheadings 2>/dev/null || true)
            if [[ -n "$mount_source" ]] && [[ ! -e "$mount_source" ]]; then
                log "Found stale mount: $mount_point -> $mount_source (device gone)"
                # Automatically unmount the stale mount
                if umount "$mount_point" 2>/dev/null; then
                    log "Successfully unmounted stale mount: $mount_point"
                    needs_cleanup=true
                else
                    log "Failed to unmount stale mount: $mount_point"
                fi
            fi
        fi
        
        if [[ "$needs_cleanup" == true ]]; then
            # Extract the folder name from the mount point path
            local folder_name="/${mount_point##*/}"
            log "Found unmounted storage: $folder_name"
            
            # Find the corresponding Nextcloud external storage entry
            local storage_id
            storage_id=$("$NEXTCLOUD_OCC" files_external:list | grep "$folder_name" | awk '{print $2}' || true)
            
            # Remove the external storage entry if it exists
            if [[ -n "$storage_id" ]]; then
                log "Removing external storage ID: $storage_id"
                "$NEXTCLOUD_OCC" files_external:delete -y "$storage_id"
            fi
        fi
    done
}

# Get appropriate mount options based on filesystem type
# Different filesystems require different permission handling
get_mount_options() {
    local fs_type="$1"
    
    case "$fs_type" in
        vfat|exfat)
            # FAT filesystems: set ownership via mount options
            echo "rw,uid=$uid,gid=$gid"
            ;;
        ntfs)
            # NTFS: set ownership via mount options  
            echo "rw,uid=$uid,gid=$gid"
            ;;
        ext4|ext3|ext2)
            # Linux filesystems: use regular permissions (chown after mount)
            echo "rw"
            ;;
        *)
            # Unsupported filesystem
            return 1
            ;;
    esac
}

# Get the mount type parameter for specific filesystems that need it
get_mount_type() {
    local fs_type="$1"
    
    case "$fs_type" in
        ntfs)
            # Use modern ntfs3 driver
            echo "ntfs3"
            ;;
        exfat)
            # Explicitly specify exfat type
            echo "exfat"
            ;;
        *)
            # No special type needed
            echo ""
            ;;
    esac
}

# Mount a USB device and create corresponding Nextcloud external storage
mount_device() {
    local device="$1"    # Device path (e.g., /dev/sda1)
    local fs_type="$2"   # Filesystem type (e.g., vfat, ext4)
    local label="$3"     # Device label or basename
    
    # Create mount point directory
    local mount_point="$MOUNT_DIR/$label"
    mkdir -p "$mount_point"
    
    # Get filesystem-specific mount options
    local mount_opts
    mount_opts=$(get_mount_options "$fs_type")
    if [[ $? -ne 0 ]]; then
        log "Unsupported filesystem type: $fs_type for $device"
        return 1
    fi
    
    # Build mount command with appropriate type and options
    local mount_type
    mount_type=$(get_mount_type "$fs_type")
    
    local mount_cmd="mount"
    [[ -n "$mount_type" ]] && mount_cmd+=" -t $mount_type"
    mount_cmd+=" -o $mount_opts $device $mount_point"
    
    log "Mounting $device ($fs_type) at $mount_point"
    if eval "$mount_cmd"; then
        # For Linux filesystems, set ownership after mounting
        if [[ "$fs_type" =~ ^ext[234]$ ]]; then
            chown -R "$NEXTCLOUD_USER:$NEXTCLOUD_USER" "$mount_point"
        fi
        
        # NTFS sometimes needs time to settle
        if [[ "$fs_type" == "ntfs" ]]; then
            sleep 15
        fi
        
        log "Successfully mounted $device"
        # Create Nextcloud external storage entry pointing to the mount
        "$NEXTCLOUD_OCC" files_external:create "/$label" local null::null -c datadir="$mount_point"
        return 0
    else
        log "Failed to mount $device"
        # Clean up empty mount point on failure
        rmdir "$mount_point" 2>/dev/null || true
        return 1
    fi
}

# Get a unique label for a device to prevent mount point conflicts
# Uses filesystem label + device name to ensure uniqueness
get_device_label() {
    local device="$1"
    local fs_label
    local device_name
    
    # Get filesystem label if it exists
    fs_label=$(blkid -o value -s LABEL "$device" 2>/dev/null || true)
    # Get device basename (e.g., "sda1")
    device_name=$(basename "$device")
    
    if [[ -n "$fs_label" ]]; then
        # Use label_devicename format to ensure uniqueness
        echo "${fs_label}_${device_name}"
    else
        # No label, just use device name
        echo "$device_name"
    fi
}

# Check if a device is already mounted somewhere
is_device_mounted() {
    local device="$1"
    findmnt -S "$device" &>/dev/null
}

# Determine if a device should be skipped (not mounted)
# Skips system partitions, already mounted system drives, and tiny partitions
should_skip_device() {
    local device="$1"
    local label="$2"
    
    # Skip system/boot partitions by label (case-insensitive)
    case "${label,,}" in
        firmware|efi|boot|recovery|system|*swap*)
            return 0  # Skip these
            ;;
    esac
    
    # Skip if device is currently mounted in system directories
    if findmnt -S "$device" | grep -qE '^\s*(/|/boot|/efi|/recovery)'; then
        return 0  # Skip system mounts
    fi
    
    # Skip devices smaller than 64MB (likely system partitions)
    local size_bytes
    size_bytes=$(lsblk -bno SIZE "$device" 2>/dev/null || echo "0")
    if [[ "$size_bytes" -lt 67108864 ]]; then
        return 0  # Skip tiny partitions
    fi
    
    return 1  # Don't skip - device is safe to mount
}

# Scan for and mount all eligible USB storage devices
process_mountable_devices() {
    log "Scanning for mountable devices..."
    mkdir -p "$MOUNT_DIR"
    
    local mounted_any=false
    
    # Process all block devices (disks and partitions)
    while IFS= read -r device; do
        # Skip if already mounted
        is_device_mounted "$device" && continue
        
        # Skip if no filesystem detected
        local fs_type
        fs_type=$(blkid -o value -s TYPE "$device" 2>/dev/null || true)
        [[ -n "$fs_type" ]] || continue
        
        # Get device label for mount point and filtering
        local label
        label=$(get_device_label "$device")
        
        # Skip system partitions and other unwanted devices
        if should_skip_device "$device" "$label"; then
            log "Skipping system/boot device: $device ($label)"
            continue
        fi
        
        # Attempt to mount the device
        if mount_device "$device" "$fs_type" "$label"; then
            mounted_any=true
        fi
        
    done < <(lsblk -rpno NAME,TYPE | awk '$2=="disk" || $2=="part" {print $1}' | sort -u)
    
    if [[ "$mounted_any" == false ]]; then
        log "No new devices mounted"
    fi
}

# Main function - entry point for the script
main() {
    log "Starting USB device management"
    
    # First, clean up any stale mounts and external storage entries
    cleanup_unmounted_storage
    
    # Then, mount any new USB devices that were plugged in
    process_mountable_devices
    
    log "USB device management completed"
}

# Run the main function with all command line arguments
main "$@"

