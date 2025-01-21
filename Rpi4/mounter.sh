#!/bin/bash
uid=$(id -u nextcloud)
gid=$(id -g nextcloud)
# Define the directory where you want to mount USB devices
    MOUNT_DIR="/mnt/usb"
    # Define the permissions you want to set
    MOUNT_PERMISSIONS="755"
    # Define the user who should own the mounted directories
    MOUNT_USER="nextcloud"

    # Create the mount directory if it does not exist
    mkdir -p "$MOUNT_DIR"

    # Find all unmounted USB devices
for device in $(lsblk -rpno NAME,TYPE | grep 'disk' | awk '{print $1}'); do
    # Check if the device is already mounted
    if ! mount | grep -q "$device"; then
        # Find all partitions on the device
        partitions=$(lsblk -rpno NAME,TYPE | grep -E "^$device" | awk '{print $1}')
        has_mounted=false

        # Loop through all partitions of the device
        for partition in $partitions; do
            # If the partition is the whole device (like /dev/sda), check if it has a filesystem
            if [ "$partition" = "$device" ]; then
                fs_type=$(blkid -o value -s TYPE "$device")
                # Check if a filesystem is detected on the whole device
                if [ -n "$fs_type" ]; then
                    # Get the label of the device (if any)
                    device_label=$(blkid -o value -s LABEL "$device")
                    # If LABEL is empty, use the device name (basename)
                    if [ -z "$device_label" ]; then
                        device_label=$(basename "$device")
                    fi
                    # Create a subdirectory for the mount
                    device_mount_dir="$MOUNT_DIR/$device_label"
                    mkdir -p "$device_mount_dir"
                    # Decide the mount options based on the filesystem type
                    if [ "$fs_type" = "vfat" ]; then
                        # Mount for vfat filesystem
                        mount -o rw,uid=$uid,gid=$gid "$device" "$device_mount_dir"
                    elif [ "$fs_type" = "ext4" ]; then
                        # Mount for ext4 filesystem
                        mount -o rw "$device" "$device_mount_dir"
                        chown -R nextcloud:nextcloud "$device_mount_dir"
		            elif [ "$fs_type" = "exfat" ]; then
                        # Mount for exfat filesystem
                        mount -t exfat -o rw,uid=$uid,gid=$gid "$device" "$device_mount_dir"
                    else
                        echo "Unsupported filesystem type: $fs_type for $device"
                        continue
                    fi

                    # Check if the mount was successful
                    if [ $? -eq 0 ]; then
                        echo "Mounted $device at $device_mount_dir"
                        # Nextcloud configuration for external storage
                        /run/current-system/sw/bin/nextcloud-occ files_external:create "/$(basename "$device_label")" local null::null -c datadir="$device_mount_dir"
                        has_mounted=true
                    else
                        echo "Failed to mount $device"
                    fi
                fi
            else
                # For actual partitions (like /dev/sda1)
                if ! mount | grep -q "$partition"; then
                    # Check the filesystem type of the partition
                    fs_type=$(blkid -o value -s TYPE "$partition")
                    # Get the label of the partition (if any)
                    partition_label=$(blkid -o value -s LABEL "$partition")
                    # If LABEL is empty, use the partition name (basename)
                    if [ -z "$partition_label" ]; then
                        partition_label=$(basename "$partition")
                    fi
                    # Create a subdirectory for the mount
                    device_mount_dir="$MOUNT_DIR/$(basename "$partition_label")"
                    mkdir -p "$device_mount_dir"

                    # Decide the mount options based on the filesystem type
                    if [ "$fs_type" = "vfat" ]; then
                        # Mount for vfat filesystem
                        mount -o rw,uid=$uid,gid=$gid "$partition" "$device_mount_dir"
                    elif [ "$fs_type" = "ext4" ]; then
                        # Mount for ext4 filesystem
                        mount -o rw "$partition" "$device_mount_dir"
			            chown -R nextcloud:nextcloud "$device_mount_dir"
                    elif [ "$fs_type" = "exfat" ]; then
                        # Mount for exfat filesystem
                        mount -t exfat -o rw,uid=$uid,gid=$gid "$partition" "$device_mount_dir"
                    else
                        echo "Unsupported filesystem type: $fs_type for $partition"
                        continue
                    fi

                    # Check if the mount was successful
                    if [ $? -eq 0 ]; then
                        echo "Mounted $partition at $device_mount_dir"
                        # Nextcloud configuration for external storage
                        /run/current-system/sw/bin/nextcloud-occ files_external:create "/$(basename "$partition_label")" local null::null -c datadir="$device_mount_dir"
                        has_mounted=true
                    else
                        echo "Failed to mount $partition"
                    fi
                fi
            fi
        done

        # If no partitions were mounted, and the whole device was not mounted, output a message
        if [ "$has_mounted" = false ]; then
            echo "No partitions or valid filesystem found to mount for device $device"
        fi
    fi
done

########## Now the ummounter part #################

# Specify the directory to check
CHECK_DIR="/mnt/usb"

# Loop through each directory in the specified directory
for mount_point in "$CHECK_DIR"/*; do
    echo "1"
    if [ -d "$mount_point" ]; then
        # Check if the mount point is mounted
        if ! lsblk -o MOUNTPOINT | grep -q "$mount_point"; then
            folder_name="/${mount_point##*/}"
	        echo "Mount point without device: $folder_name"
            i=$(/run/current-system/sw/bin/nextcloud-occ files_external:list | grep "$folder_name" | awk '{print $2}')
            echo "$i"
            if [ -n "$i" ]; then 
                /run/current-system/sw/bin/nextcloud-occ files_external:delete -y $i
            fi
	    fi
    fi
done
