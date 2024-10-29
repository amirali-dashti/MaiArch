#!/bin/bash

# Set the output file for Archinstall
OUTPUT_FILE="user_config.json"

# Function to create JSON configuration
create_json() {
    cat <<EOF > "$OUTPUT_FILE"
{
    "!users": [
        {
            "sudo": $1,
            "username": "$2"
        }
    ],
    "disk_config": {
        "config_type": "default_layout",
        "device_modifications": [
            {
                "device": "$3",
                "partitions": [
                    {
                        "btrfs": [],
                        "flags": [
                            "Boot"
                        ],
                        "fs_type": "fat32",
                        "size": {
                            "sector_size": null,
                            "unit": "MiB",
                            "value": 512
                        },
                        "mount_options": [],
                        "mountpoint": "/boot",
                        "obj_id": "2c3fa2d5-2c79-4fab-86ec-22d0ea1543c0",
                        "start": {
                            "sector_size": null,
                            "unit": "MiB",
                            "value": 1
                        },
                        "status": "create",
                        "type": "primary"
                    },
                    {
                        "btrfs": [],
                        "flags": [],
                        "fs_type": "ext4",
                        "size": {
                            "sector_size": null,
                            "unit": "GiB",
                            "value": 20
                        },
                        "mount_options": [],
                        "mountpoint": "/",
                        "obj_id": "3e7018a0-363b-4d05-ab83-8e82d13db208",
                        "start": {
                            "sector_size": null,
                            "unit": "MiB",
                            "value": 513
                        },
                        "status": "create",
                        "type": "primary"
                    },
                    {
                        "btrfs": [],
                        "flags": [],
                        "fs_type": "ext4",
                        "size": {
                            "sector_size": null,
                            "unit": "Percent",
                            "value": 100
                        },
                        "mount_options": [],
                        "mountpoint": "/home",
                        "obj_id": "ce58b139-f041-4a06-94da-1f8bad775d3f",
                        "start": {
                            "sector_size": null,
                            "unit": "GiB",
                            "value": 20
                        },
                        "status": "create",
                        "type": "primary"
                    }
                ],
                "wipe": true
            }
        ]
    }
}
EOF
}

# Use dialog to get user input for username
dialog --title "User Configuration for Archinstall" --clear --inputbox "Enter username for the new user:" 8 40 "archinstall" 2> temp_username.txt

# Read the username from the temp file
USERNAME=$(<temp_username.txt)

# Confirm sudo privileges
dialog --title "Sudo Privileges" --yesno "Should this user have sudo privileges?" 7 60
if [ $? -eq 0 ]; then
    SUDO="true"
else
    SUDO="false"
fi

# Use dialog to get disk device
dialog --title "Disk Configuration" --inputbox "Enter the disk device (e.g., /dev/sda):" 8 40 "/dev/sda" 2> temp_device.txt

# Read the disk device from the temp file
DISK_DEVICE=$(<temp_device.txt)

# Create the JSON configuration file
create_json "$SUDO" "$USERNAME" "$DISK_DEVICE"

# Cleanup
rm temp_username.txt temp_device.txt

# Notify the user that the configuration file has been created
dialog --title "Configuration Complete" --msgbox "The configuration file has been created: $OUTPUT_FILE" 6 40

archinstall --config $OUTPUT_FILE

# End the script
exit 0
