#!/bin/bash

set -euo pipefail

readonly NEXTCLOUD_USER="nextcloud"
readonly MOUNT_DIR="/mnt/usb"
readonly NEXTCLOUD_OCC="/run/current-system/sw/bin/nextcloud-occ"

readonly uid=$(id -u "$NEXTCLOUD_USER")
readonly gid=$(id -g "$NEXTCLOUD_USER")

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

cleanup_unmounted_storage() {
    log "Cleaning up unmounted external storages..."
    
    for mount_point in "$MOUNT_DIR"/*; do
        [[ -d "$mount_point" ]] || continue
        
        if ! findmnt -M "$mount_point" &>/dev/null; then
            local folder_name="/${mount_point##*/}"
            log "Found unmounted storage: $folder_name"
            
            local storage_id
            storage_id=$("$NEXTCLOUD_OCC" files_external:list | grep "$folder_name" | awk '{print $2}' || true)
            
            if [[ -n "$storage_id" ]]; then
                log "Removing external storage ID: $storage_id"
                "$NEXTCLOUD_OCC" files_external:delete -y "$storage_id"
            fi
        fi
    done
}

get_mount_options() {
    local fs_type="$1"
    
    case "$fs_type" in
        vfat|exfat)
            echo "rw,uid=$uid,gid=$gid"
            ;;
        ntfs)
            echo "rw,uid=$uid,gid=$gid"
            ;;
        ext4|ext3|ext2)
            echo "rw"
            ;;
        *)
            return 1
            ;;
    esac
}

get_mount_type() {
    local fs_type="$1"
    
    case "$fs_type" in
        ntfs)
            echo "ntfs3"
            ;;
        exfat)
            echo "exfat"
            ;;
        *)
            echo ""
            ;;
    esac
}

mount_device() {
    local device="$1"
    local fs_type="$2"
    local label="$3"
    
    local mount_point="$MOUNT_DIR/$label"
    mkdir -p "$mount_point"
    
    local mount_opts
    mount_opts=$(get_mount_options "$fs_type")
    if [[ $? -ne 0 ]]; then
        log "Unsupported filesystem type: $fs_type for $device"
        return 1
    fi
    
    local mount_type
    mount_type=$(get_mount_type "$fs_type")
    
    local mount_cmd="mount"
    [[ -n "$mount_type" ]] && mount_cmd+=" -t $mount_type"
    mount_cmd+=" -o $mount_opts $device $mount_point"
    
    log "Mounting $device ($fs_type) at $mount_point"
    if eval "$mount_cmd"; then
        if [[ "$fs_type" =~ ^ext[234]$ ]]; then
            chown -R "$NEXTCLOUD_USER:$NEXTCLOUD_USER" "$mount_point"
        fi
        
        if [[ "$fs_type" == "ntfs" ]]; then
            sleep 15
        fi
        
        log "Successfully mounted $device"
        "$NEXTCLOUD_OCC" files_external:create "/$label" local null::null -c datadir="$mount_point"
        return 0
    else
        log "Failed to mount $device"
        rmdir "$mount_point" 2>/dev/null || true
        return 1
    fi
}

get_device_label() {
    local device="$1"
    local label
    
    label=$(blkid -o value -s LABEL "$device" 2>/dev/null || true)
    if [[ -z "$label" ]]; then
        label=$(basename "$device")
    fi
    
    echo "$label"
}

is_device_mounted() {
    local device="$1"
    findmnt -S "$device" &>/dev/null
}

should_skip_device() {
    local device="$1"
    local label="$2"
    
    # Skip system/boot partitions by label
    case "${label,,}" in
        firmware|efi|boot|recovery|system|*swap*)
            return 0
            ;;
    esac
    
    # Skip if device is currently mounted anywhere in system directories
    if findmnt -S "$device" | grep -qE '^\s*(/|/boot|/efi|/recovery)'; then
        return 0
    fi
    
    # Skip devices smaller than 64MB (likely system partitions)
    local size_bytes
    size_bytes=$(lsblk -bno SIZE "$device" 2>/dev/null || echo "0")
    if [[ "$size_bytes" -lt 67108864 ]]; then
        return 0
    fi
    
    return 1
}

process_mountable_devices() {
    log "Scanning for mountable devices..."
    mkdir -p "$MOUNT_DIR"
    
    local mounted_any=false
    
    while IFS= read -r device; do
        is_device_mounted "$device" && continue
        
        local fs_type
        fs_type=$(blkid -o value -s TYPE "$device" 2>/dev/null || true)
        [[ -n "$fs_type" ]] || continue
        
        local label
        label=$(get_device_label "$device")
        
        if should_skip_device "$device" "$label"; then
            log "Skipping system/boot device: $device ($label)"
            continue
        fi
        
        if mount_device "$device" "$fs_type" "$label"; then
            mounted_any=true
        fi
        
    done < <(lsblk -rpno NAME,TYPE | awk '$2=="disk" || $2=="part" {print $1}' | sort -u)
    
    if [[ "$mounted_any" == false ]]; then
        log "No new devices mounted"
    fi
}

main() {
    log "Starting USB device management"
    
    cleanup_unmounted_storage
    process_mountable_devices
    
    log "USB device management completed"
}

main "$@"

