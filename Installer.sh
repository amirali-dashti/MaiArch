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

# Collect hostname
hostname=$(collect_input "Enter your hostname:")

# Collect disk selection
disk=$(collect_menu_selection "Disk Selection" "Select a disk to install Arch Linux:" "4 \
1 "/dev/sda" \
2 "/dev/sdb" \
3 "/dev/nvme0n1" \
4 "Exit"")

# Collect timezone
timezone=$(collect_menu_selection "Timezone Selection" "Select your timezone:" "5 \
1 "UTC" \
2 "America/New_York" \
3 "Europe/Berlin" \
4 "Asia/Tokyo" \
5 "America/Sao_Paulo"")

# Collect language
language=$(collect_menu_selection "Language Selection" "Select your language:" "5 \
1 "en_US.UTF-8" \
2 "de_DE.UTF-8" \
3 "ja_JP.UTF-8" \
4 "es_ES.UTF-8" \
5 "Exit"")

# Collect network configuration
network_config=$(collect_menu_selection "Network Configuration" "Select your network type:" "4 \
1 "none" \
2 "dhcp" \
3 "static" \
4 "Exit"")

# Collect package selection
packages=$(collect_package_selection "Package Selection" "Select additional packages to install:" "5 \
1 "base-devel" off \
2 "vim" off \
3 "git" off \
4 "networkmanager" off \
5 "sddm" off")

# Prepare the JSON structure
config_path="$HOME/install_config.json"

# Create JSON file with structured data
{
  echo "{"
  echo "  \"__separator__\": null,"
  echo "  \"hostname\": \"$hostname\","
  echo "  \"timezone\": \"$timezone\","
  echo "  \"locale_config\": {"
  echo "    \"kb_layout\": \"us\","
  echo "    \"sys_enc\": \"UTF-8\","
  echo "    \"sys_lang\": \"$language\""
  echo "  },"
  echo "  \"network_config\": {"
  echo "    \"type\": \"$network_config\""
  echo "  },"
  echo "  \"disk_config\": {"
  echo "    \"config_type\": \"default_layout\","
  echo "    \"device_modifications\": ["
  echo "      {"
  echo "        \"device\": \"$disk\","
  echo "        \"partitions\": ["
  echo "          {"
  echo "            \"fs_type\": \"btrfs\","
  echo "            \"mountpoint\": null,"
  echo "            \"status\": \"create\","
  echo "            \"type\": \"primary\""
  echo "          }"
  echo "        ],"
  echo "        \"wipe\": true"
  echo "      }"
  echo "    ]"
  echo "  },"
  echo "  \"packages\": [$(echo "$packages" | tr '\n' ',' | sed 's/,$//')],"
  echo "  \"archinstall-language\": \"English\","
  echo "  \"script\": \"guided\""
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
