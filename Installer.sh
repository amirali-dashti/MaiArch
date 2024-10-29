#!/bin/bash

# Function to check internet connectivity
function check_internet() {
    if ping -c 1 -w 1 google.com > /dev/null 2>&1; then
        return 0
    else
        yad --error --title="Error" --text="No internet connection detected. Please check your network settings."
        exit 1
    fi
}

# Function to set the keyboard layout
function set_keyboard_layout() {
    KEYBOARD_LAYOUT=$(yad --entry --title="Keyboard Layout" --text="Set your keyboard layout (e.g., us, fr, de):")
    if [[ -z "$KEYBOARD_LAYOUT" ]]; then
        yad --error --title="Error" --text="No keyboard layout entered. Exiting."
        exit 1
    fi
    loadkeys "$KEYBOARD_LAYOUT"
}

# Function to partition the disk
function partition_disk() {
    if ! cfdisk /dev/sda; then
        yad --error --title="Error" --text="Failed to partition the disk. Please check the device."
        exit 1
    fi
}

# Function to format partitions
function format_partitions() {
    if ! mkfs.ext4 /dev/sda1; then
        yad --error --title="Error" --text="Failed to format /dev/sda1."
        exit 1
    fi

    if ! mkfs.ext4 /dev/sda2; then
        yad --error --title="Error" --text="Failed to format /dev/sda2."
        exit 1
    fi

    if ! swapon /dev/sda2; then
        yad --error --title="Error" --text="Failed to enable swap on /dev/sda2."
        exit 1
    fi
}

# Function to mount partitions
function mount_partitions() {
    mkdir -p /mnt
    if ! mount /dev/sda1 /mnt; then
        yad --error --title="Error" --text="Failed to mount /dev/sda1."
        exit 1
    fi

    mkdir -p /mnt/boot
    if ! mount /dev/sda2 /mnt/boot; then
        yad --error --title="Error" --text="Failed to mount /dev/sda2."
        exit 1
    fi
}

# Function to install the base system
function install_base_system() {
    if ! pacstrap /mnt base base-devel; then
        yad --error --title="Error" --text="Failed to install the base system."
        exit 1
    fi
}

# Function to generate the fstab file
function generate_fstab() {
    if ! genfstab -U /mnt >> /mnt/etc/fstab; then
        yad --error --title="Error" --text="Failed to generate fstab file."
        exit 1
    fi
}

# Function to chroot into the new system
function chroot_into_system() {
    if ! arch-chroot /mnt; then
        yad --error --title="Error" --text="Failed to chroot into the new system."
        exit 1
    fi
}

# Function to set the root password
function set_root_password() {
    if ! passwd; then
        yad --error --title="Error" --text="Failed to set the root password."
        exit 1
    fi
}

# Function to configure the network
function configure_network() {
    # Assuming you want to implement network configuration later
    yad --info --title="Network Configuration" --text="Network configuration setup. Implement as needed."
}

# Function to configure the system clock
function configure_clock() {
    if ! timedatectl set-timezone Europe/Berlin; then
        yad --error --title="Error" --text="Failed to configure the system clock."
        exit 1
    fi
}

# Function to install a bootloader
function install_bootloader() {
    if ! grub-install /dev/sda; then
        yad --error --title="Error" --text="Failed to install the bootloader."
        exit 1
    fi

    if ! grub-mkconfig -o /boot/grub/grub.cfg; then
        yad --error --title="Error" --text="Failed to generate grub configuration."
        exit 1
    fi
}

# Main function
function main() {
    check_internet
    set_keyboard_layout
    partition_disk
    format_partitions
    mount_partitions
    install_base_system
    generate_fstab
    chroot_into_system
    set_root_password
    configure_network
    configure_clock
    install_bootloader
    yad --info --title="Completion" --text="Installation complete! Reboot your system."
}

main
