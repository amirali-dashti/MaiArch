#!/bin/bash

# Function to print a formatted message
function print_info() {
  echo -e "\n\033[1;32m$1\033[0m"
}

# Function to prompt for user input
function prompt_user() {
  read -p "$1: " input
  echo "$input"
}

# Function to prompt for password securely
function prompt_password() {
  dialog --passwordbox "$1" 10 60 2> password.txt
  PASSWORD=$(<password.txt)
  rm password.txt
}

# Start of the installation process
print_info "Starting Arch Linux Installation..."

# Partitioning (Placeholder)
print_info "Partitioning the disk..."
# Uncomment and modify as needed
# sfdisk /dev/sda << EOF
# # partitioning commands here
# EOF
# if [ $? -ne 0 ]; then
#   echo "Partitioning failed"
#   exit 1
# fi

# Formatting
print_info "Formatting partitions..."
mkfs.ext4 /dev/sda1 || { echo "Formatting failed"; exit 1; }
mkswap /dev/sda2 || { echo "Swap formatting failed"; exit 1; }
swapon /dev/sda2 || { echo "Enabling swap failed"; exit 1; }

# Mounting
print_info "Mounting partitions..."
mount /dev/sda1 /mnt || { echo "Mounting failed"; exit 1; }

# Pacman Configuration
print_info "Configuring package manager..."
# Example: Customize mirrorlist here
# nano /etc/pacman.d/mirrorlist

# Package Installation
print_info "Installing base system..."
pacstrap /mnt base base-devel || { echo "Base system installation failed"; exit 1; }

# Chroot
print_info "Entering chroot environment..."
arch-chroot /mnt /bin/bash <<EOF

# Configuration inside chroot
print_info "Configuring system..."

# Set timezone
timedatectl set-timezone YOUR_TIMEZONE

# Generate locales
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
HOSTNAME=\$(prompt_user "Enter hostname")
echo "\$HOSTNAME" > /etc/hostname
# Update hosts file
echo "127.0.0.1  localhost" >> /etc/hosts
echo "::1        localhost" >> /etc/hosts
echo "127.0.1.1  \$HOSTNAME.localdomain  \$HOSTNAME" >> /etc/hosts

# User Creation
USERNAME=\$(prompt_user "Username")
prompt_password "Enter password for \$USERNAME"
echo "\$USERNAME:\$PASSWORD" | chpasswd
usermod -aG wheel "\$USERNAME"

# Configure sudoers (allow wheel group to use sudo)
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Network Configuration
print_info "Configuring network..."
# Example: Install network utilities
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

# Boot Loader Installation
print_info "Installing boot loader..."
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# Exit Chroot and Cleanup
print_info "Exiting chroot environment..."
umount -R /mnt || { echo "Unmounting failed"; exit 1; }

# Inform user to reboot manually
print_info "Installation complete. Please reboot the system manually."

# End of the script
