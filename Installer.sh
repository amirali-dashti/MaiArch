#!/bin/bash

# Function to display an error message and exit
function error_exit {
    dialog --msgbox "$1" 6 40
    exit 1
}

# Function to collect user input with validation
function collect_input {
    local prompt="$1"
    local input_var

    while true; do
        input_var=$(dialog --inputbox "$prompt" 8 40 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 ]]; then
            error_exit "$prompt cancelled."
        fi

        # Validate input (non-empty)
        if [[ -z "$input_var" ]]; then
            dialog --msgbox "Input cannot be empty. Please try again." 6 40
        else
            echo "$input_var"
            break
        fi
    done
}

# Function to collect password input
function collect_password {
    local prompt="$1"
    local password_var

    password_var=$(dialog --passwordbox "$prompt" 8 40 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
        error_exit "$prompt cancelled."
    fi
    echo "$password_var"
}

# Function to collect menu selection
function collect_menu_selection {
    local title="$1"
    local prompt="$2"
    local options="$3"
    
    local selection
    selection=$(dialog --title "$title" --menu "$prompt" 15 50 $options 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        error_exit "$title selection cancelled."
    fi
    
    echo "$selection"
}

# Function to collect package selection
function collect_package_selection {
    local title="$1"
    local prompt="$2"
    local options="$3"
    
    local packages
    packages=$(dialog --title "$title" --checklist "$prompt" 15 50 $options 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        error_exit "$title selection cancelled."
    fi
    
    echo "$packages"
}

# Collect disk selection
disk=$(collect_menu_selection "Disk Selection" "Select a disk to install Arch Linux:" "4 \
1 "/dev/sda" \
2 "/dev/sdb" \
3 "/dev/nvme0n1" \
4 "Exit"")

# Collect username
username=$(collect_input "Enter your username:")

# Collect password
password=$(collect_password "Enter your password:")

# Collect timezone
timezone=$(collect_menu_selection "Timezone Selection" "Select your timezone:" "5 \
1 "UTC" \
2 "America/New_York" \
3 "Europe/Berlin" \
4 "Asia/Tokyo" \
5 "Exit"")

# Collect language
language=$(collect_menu_selection "Language Selection" "Select your language:" "5 \
1 "en_US.UTF-8" \
2 "de_DE.UTF-8" \
3 "ja_JP.UTF-8" \
4 "es_ES.UTF-8" \
5 "Exit"")

# Collect package selection
packages=$(collect_package_selection "Package Selection" "Select additional packages to install:" "5 \
1 "base-devel" off \
2 "vim" off \
3 "git" off \
4 "networkmanager" off \
5 "Exit"")

# Convert selected packages to JSON format
packages_list=$(echo "$packages" | tr '\n' ',' | sed 's/,$//')

# Set default config path for saving JSON
config_path="$HOME/install_config.json"

# Create the JSON structure and save to file
{
  echo "{"
  echo "  \"disk\": \"$disk\","
  echo "  \"username\": \"$username\","
  echo "  \"password\": \"$password\","
  echo "  \"timezone\": \"$timezone\","
  echo "  \"language\": \"$language\","
  echo "  \"packages\": [$packages_list]"
  echo "}"
} > "$config_path"

# Check if the JSON file was created successfully
if [[ $? -ne 0 ]]; then
    error_exit "Failed to save configuration to $config_path."
fi

# Inform the user
dialog --msgbox "Configuration saved to $config_path" 5 40

# Run archinstall with the generated JSON file
archinstall --config "$config_path"
