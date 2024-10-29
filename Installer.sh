#!/bin/bash

# Function to select GUI tool
function select_gui() {
    GUI=$(dialog --title "Select GUI Tool" --menu "Choose your GUI tool:" 15 50 3 \
        1 "dialog" \
        2 "yad" \
        3 "zenity" \
        3>&1 1>&2 2>&3 3>&-)

    case $GUI in
        1) GUI_TOOL="dialog";;
        2) GUI_TOOL="yad";;
        3) GUI_TOOL="zenity";;
        *) echo "Invalid selection. Exiting." && exit 1;;
    esac
}

# Function to display error messages
function show_error() {
    case $GUI_TOOL in
        dialog) dialog --title "Error" --msgbox "$1" 6 50;;
        yad) yad --error --title="Error" --text="$1";;
        zenity) zenity --error --title="Error" --text="$1";;
    esac
}

# Function to display information messages
function show_info() {
    case $GUI_TOOL in
        dialog) dialog --title "Info" --msgbox "$1" 6 50;;
        yad) yad --info --title="Info" --text="$1";;
        zenity) zenity --info --title="Info" --text="$1";;
    esac
}

# Function to ask for user input for keyboard layout
function set_keyboard_layout() {
    KEYBOARD_LAYOUT=$(case $GUI_TOOL in
        dialog) dialog --inputbox "Set your keyboard layout (e.g., us, fr, de):" 8 50 3>&1 1>&2 2>&3 3>&-;;
        yad) yad --entry --title="Keyboard Layout" --text="Set your keyboard layout (e.g., us, fr, de):";;
        zenity) zenity --entry --title="Keyboard Layout" --text="Set your keyboard layout (e.g., us, fr, de):";;
    esac)

    if [[ -z "$KEYBOARD_LAYOUT" ]]; then
        show_error "No keyboard layout entered. Exiting."
        exit 1
    fi
    loadkeys "$KEYBOARD_LAYOUT"
}

# Function to get root password
function get_root_password() {
    ROOT_PASSWORD=$(case $GUI_TOOL in
        dialog) dialog --passwordbox "Enter root password:" 8 50 3>&1 1>&2 2>&3 3>&-;;
        yad) yad --entry --title="Root Password" --text="Enter root password:" --hide-text;;
        zenity) zenity --password --title="Root Password";;
    esac)

    if [[ -z "$ROOT_PASSWORD" ]]; then
        show_error "No password entered. Exiting."
        exit 1
    fi

    echo "$ROOT_PASSWORD" | passwd --stdin root  # Adjust for your system's password management
}

# Function to check internet connectivity
function check_internet() {
    if ping -c 1 -w 1 google.com > /dev/null 2>&1; then
        return 0
    else
        show_error "No internet connection detected. Please check your network settings."
        exit 1
    fi
}

# Other functions (partition_disk, format_partitions, mount_partitions, etc.) remain unchanged
# You can implement those similarly by replacing their dialog or yad calls with respective ones.

# Main function
function main() {
    select_gui
    check_internet
    set_keyboard_layout
    get_root_password
    # Call other functions as needed
    show_info "Installation complete! Reboot your system."
}

main
