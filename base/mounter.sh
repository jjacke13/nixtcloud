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

# Database configuration
readonly USB_DB="/var/lib/nextcloud/usb_storage_map.txt"

# Look up storage info by UUID
# Returns: mount_id|mount_path|label (or empty if not found)
db_lookup_by_uuid() {
    local uuid="$1"
    grep "^${uuid}|" "$USB_DB" 2>/dev/null | tail -n1 | cut -d'|' -f2-
}

# Add new entry to database
# Usage: db_add_entry UUID mount_id mount_path label
db_add_entry() {
    local uuid="$1"
    local mount_id="$2"
    local mount_path="$3"
    local label="$4"

    echo "${uuid}|${mount_id}|${mount_path}|${label}" >> "$USB_DB"
    log "Added to DB: UUID=${uuid} mount_id=${mount_id} path=${mount_path}"
}

# Get mount_id from database by UUID
db_get_mount_id() {
    local uuid="$1"
    db_lookup_by_uuid "$uuid" | cut -d'|' -f1
}

# Get mount_path from database by UUID
db_get_mount_path() {
    local uuid="$1"
    db_lookup_by_uuid "$uuid" | cut -d'|' -f2
}

# Clean up Nextcloud external storage entries for devices that are no longer mounted
# This handles both properly unmounted devices and stale mounts from unplugged devices
cleanup_unmounted_storage() {
    log "Cleaning up unmounted external storages..."

    for mount_point in "$MOUNT_DIR"/*; do
        [[ -d "$mount_point" ]] || continue

        local needs_cleanup=false

        if ! findmnt -M "$mount_point" &>/dev/null; then
            # Mount point is not mounted, mark for cleanup
            log "Found unmounted storage at $mount_point, marking for cleanup"
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
            
            # Hide the external storage entry if it exists (preserve for preview reuse)
            if [[ -n "$storage_id" ]]; then
                log "Hiding external storage ID: $storage_id (adding to disabled-storage group)"
                "$NEXTCLOUD_OCC" files_external:applicable "$storage_id" --add-group=disabled-storage
            fi
            
            # Remove the empty mount point directory to prevent future conflicts
            if rmdir "$mount_point" 2>/dev/null; then
                log "Removed empty mount point directory: $mount_point"
            else
                log "Could not remove mount point directory (not empty?): $mount_point"
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
            # NTFS: mount with ownership, secure permissions, and force flag for dirty volumes
            # fmask=133 gives files 644 permissions, dmask=022 gives directories 755 permissions
            # chown after mounting handles existing files that ntfs3 doesn't set properly
            echo "rw,uid=$uid,gid=$gid,fmask=133,dmask=022,force"
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

# Mount a USB device and create/reuse corresponding Nextcloud external storage
mount_device() {
    local device="$1"    # Device path (e.g., /dev/sda1)
    local fs_type="$2"   # Filesystem type (e.g., vfat, ext4)
    local label="$3"     # Device label or basename

    # Get device UUID for tracking
    local device_uuid
    device_uuid=$(blkid -s UUID -o value "$device" 2>/dev/null || true)

    if [[ -z "$device_uuid" ]]; then
        log "Warning: Device $device has no UUID, skipping"
        return 1
    fi

    # Check if this UUID is already in our database
    local existing_mount_id
    existing_mount_id=$(db_get_mount_id "$device_uuid")

    local mount_point

    if [[ -n "$existing_mount_id" ]]; then
        # Known device - reuse existing storage entry and mount path
        mount_point=$(db_get_mount_path "$device_uuid")
        log "Recognized USB device (UUID: $device_uuid, mount_id: $existing_mount_id)"
        log "Will mount at previous location: $mount_point"
    else
        # New device - find available mount point (handles label conflicts)
        mount_point=$(get_available_mount_path "$device_uuid" "$label")
        log "New USB device detected (UUID: $device_uuid)"
    fi

    # Create mount point directory
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
    mount_cmd+=" -o $mount_opts $device \"$mount_point\""

    log "Mounting $device ($fs_type) at $mount_point"
    if eval "$mount_cmd"; then
        # For Linux filesystems, set ownership after mounting
        if [[ "$fs_type" =~ ^ext[234]$ ]]; then
            chown -R "$NEXTCLOUD_USER:$NEXTCLOUD_USER" "$mount_point"
        fi

        # NTFS sometimes needs time to settle and fix ownership
        if [[ "$fs_type" == "ntfs" ]]; then
            sleep 15
            # Fix ownership of existing files that ntfs3 doesn't handle properly
            chown -R "$NEXTCLOUD_USER:$NEXTCLOUD_USER" "$mount_point"
            # Set secure permissions on mount point directory for Nextcloud admin UI
            chmod 755 "$mount_point"
        fi

        log "Successfully mounted $device"

        # Handle Nextcloud external storage
        if [[ -n "$existing_mount_id" ]]; then
            # Reuse existing storage - just unhide it
            log "Re-enabling existing external storage (mount_id: $existing_mount_id)"
            "$NEXTCLOUD_OCC" files_external:applicable "$existing_mount_id" --remove-group=disabled-storage

            # Extract folder name from mount_point for scan path
            local folder_name="$(basename "$mount_point")"

            # Trigger file scan to refresh cache and detect any changes
            log "Scanning files in external storage: /$folder_name"
            "$NEXTCLOUD_OCC" files:scan --path="/admin/files/$folder_name" &
            # Run in background (&) so mounting continues without waiting for scan
        else
            # Create new external storage entry
            # Extract folder name from mount_point (includes conflict suffix if needed)
            local folder_name="$(basename "$mount_point")"
            log "Creating new external storage entry for /$folder_name"
            "$NEXTCLOUD_OCC" files_external:create "/$folder_name" local null::null -c datadir="$mount_point"

            # Get the mount_id that was just created
            local new_mount_id
            new_mount_id=$("$NEXTCLOUD_OCC" files_external:list | grep "/$folder_name" | awk '{print $2}' || true)

            if [[ -n "$new_mount_id" ]]; then
                # Add to database for future reuse
                db_add_entry "$device_uuid" "$new_mount_id" "$mount_point" "$label"
            else
                log "Warning: Could not retrieve mount_id for newly created storage"
            fi
        fi

        return 0
    else
        log "Failed to mount $device"
        # Clean up empty mount point on failure
        rmdir "$mount_point" 2>/dev/null || true
        return 1
    fi
}

# Find an available mount path, handling label conflicts
# Usage: get_available_mount_path device_uuid label
get_available_mount_path() {
    local device_uuid="$1"
    local label="$2"
    local base_path="$MOUNT_DIR/$label"
    local candidate_path="$base_path"
    local counter=2

    # Check if path is already used by a DIFFERENT UUID in database
    while true; do
        # Look up what UUID owns this path in database
        local existing_uuid
        existing_uuid=$(grep "|${candidate_path}|" "$USB_DB" 2>/dev/null | cut -d'|' -f1 || true)

        if [[ -z "$existing_uuid" ]]; then
            # Path not in database - available!
            echo "$candidate_path"
            return 0
        elif [[ "$existing_uuid" == "$device_uuid" ]]; then
            # Path owned by same UUID - our device!
            echo "$candidate_path"
            return 0
        else
            # Path owned by different UUID - try next
            candidate_path="${base_path}_${counter}"
            ((counter++))
        fi
    done
}

# Get a unique label for a device to prevent mount point conflicts
# Uses filesystem label only (UUID tracking ensures uniqueness)
get_device_label() {
    local device="$1"
    local fs_label

    # Get filesystem label if it exists
    fs_label=$(blkid -o value -s LABEL "$device" 2>/dev/null || true)

    if [[ -n "$fs_label" ]]; then
        # Use filesystem label only (UUID tracking ensures uniqueness)
        echo "$fs_label"
    else
        # No label - use UUID as fallback for mount point name
        local device_uuid
        device_uuid=$(blkid -s UUID -o value "$device" 2>/dev/null || true)
        if [[ -n "$device_uuid" ]]; then
            # Use first 8 chars of UUID for readability
            echo "usb-${device_uuid:0:8}"
        else
            # Last resort - use device name
            echo "$(basename "$device")"
        fi
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

