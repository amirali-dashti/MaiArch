#!/bin/bash

# Function to check internet connectivity
function check_internet() {
    ping -c 1 -w 1 google.com > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        return 0
    else
        echo "No internet connection detected. Please check your network settings."
        exit 1
    fi
}

# Function to set the keyboard layout
function set_keyboard_layout() {
    echo "Set your keyboard layout (e.g., us, fr, de):"
    read -r KEYBOARD_LAYOUT
    loadkeys $KEYBOARD_LAYOUT
}

# Function to partition the disk
function partition_disk() {
    echo "Partitioning the disk. Be careful!"
    # Replace `/dev/sda` with your actual disk device
    cfdisk /dev/sda
}

# Function to format partitions
function format_partitions() {
    echo "Formatting partitions..."
    # Replace `/dev/sda1` and `/dev/sda2` with your actual partition devices
    mkfs.ext4 /dev/sda1
    mkfs.ext4 /dev/sda2
    swapon /dev/sda2
}

# Function to mount partitions
function mount_partitions() {
    echo "Mounting partitions..."
    mkdir -p /mnt
    mount /dev/sda1 /mnt
    mkdir -p /mnt/boot
    mount /dev/sda2 /mnt/boot
}

# Function to install the base system
function install_base_system() {
    echo "Installing the base system..."
    pacstrap /mnt base base-devel
}

# Function to generate the fstab file
function generate_fstab() {
    echo "Generating fstab file..."
    genfstab -U /mnt >> /mnt/etc/fstab
}

# Function to chroot into the new system
function chroot_into_system() {
    echo "Chrooting into the new system..."
    arch-chroot /mnt
}

# Function to set the root password
function set_root_password() {
    echo "Setting the root password..."
    passwd
}

# Function to configure the network
function configure_network() {
    echo "Configuring the network..."
    # Edit /etc/network/interfaces or use network manager
}

# Function to configure the system clock
function configure_clock() {
    echo "Configuring the system clock..."
    timedatectl set-timezone Europe/Berlin  # Replace with your timezone
}

# Function to install a bootloader
function install_bootloader() {
    echo "Installing the bootloader..."
    # Replace `grub-mkconfig -o /boot/grub/grub.cfg` with your preferred bootloader
    grub-install /dev/sda
    grub-mkconfig -o /boot/grub/grub.cfg
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
    echo "Installation complete! Reboot your system."
}

main
