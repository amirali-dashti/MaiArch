#!/bin/bash

# Define the output JSON file
json_file="install_config.json"

# Function to display an error message and exit
function error_exit {
    dialog --msgbox "$1" 6 40
    exit 1
}

# Collect disk selection using dialog
disk=$(dialog --title "Disk Selection" --menu "Select a disk to install Arch Linux:" 15 50 4 \
1 "/dev/sda" \
2 "/dev/sdb" \
3 "/dev/nvme0n1 \
4 "Exit" 3>&1 1>&2 2>&3) || error_exit "Disk selection cancelled."

# Collect username and password
username=$(dialog --inputbox "Enter your username:" 8 40 3>&1 1>&2 2>&3) || error_exit "Username entry cancelled."
password=$(dialog --passwordbox "Enter your password:" 8 40 3>&1 1>&2 2>&3) || error_exit "Password entry cancelled."

# Collect timezone
timezone=$(dialog --title "Timezone Selection" --menu "Select your timezone:" 15 50 4 \
1 "UTC" \
2 "America/New_York" \
3 "Europe/Berlin" \
4 "Asia/Tokyo" \
5 "Exit" 3>&1 1>&2 2>&3) || error_exit "Timezone selection cancelled."

# Collect language
language=$(dialog --title "Language Selection" --menu "Select your language:" 15 50 4 \
1 "en_US.UTF-8" \
2 "de_DE.UTF-8" \
3 "ja_JP.UTF-8" \
4 "es_ES.UTF-8" \
5 "Exit" 3>&1 1>&2 2>&3) || error_exit "Language selection cancelled."

# Collect package selection
packages=$(dialog --title "Package Selection" --checklist "Select additional packages to install:" 15 50 4 \
1 "base-devel" off \
2 "vim" off \
3 "git" off \
4 "networkmanager" off \
5 "Exit" 3>&1 1>&2 2>&3) || error_exit "Package selection cancelled."

# Create the JSON structure
json_content=$(cat <<EOF
{
  "disk": "$disk",
  "username": "$username",
  "password": "$password",
  "timezone": "$timezone",
  "language": "$language",
  "packages": [$(echo "$packages" | tr '\n' ',' | sed 's/,$//')]
}
EOF
)

# Save to JSON file
echo "$json_content" > "$json_file"

# Inform the user
dialog --msgbox "Configuration saved to $json_file" 5 30

# Run archinstall with the generated JSON file
archinstall --config "$json_file"
