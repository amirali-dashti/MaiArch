#!/bin/bash

# Ensure dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "dialog could not be found, please install it first."
    exit 1
fi

# Variables
HOSTNAME=""
TIMEZONE=""
LOCALE="en_US.UTF-8"
USERNAME=""
PASSWORD=""
ROOT_PASSWORD=""
DISK=""
EFI_PARTITION=""  # For UEFI systems, if applicable

# Function to show an error message
function error_message() {
    dialog --msgbox "$1" 6 60
    exit 1
}

# Function to get user input for hostname
function get_hostname() {
    HOSTNAME=$(dialog --inputbox "Enter hostname:" 8 40 3>&1 1>&2 2>&3)
    if [ -z "$HOSTNAME" ]; then
        error_message "Hostname cannot be empty."
    fi
}

# Function to choose timezone
function choose_timezone() {
    TIMEZONE=$(dialog --inputbox "Enter your timezone (e.g., America/New_York):" 8 40 3>&1 1>&2 2>&3)
    if [ -z "$TIMEZONE" ]; then
        error_message "Timezone cannot be empty."
    fi
}

# Function to set the disk for installation
function choose_disk() {
    DISK=$(dialog --inputbox "Enter the disk to install (e.g., /dev/sda):" 8 40 3>&1 1>&2 2>&3)
    if [ -z "$DISK" ]; then
        error_message "Disk cannot be empty."
    fi

    # Check if the disk exists
    if [ ! -b "$DISK" ]; then
        error_message "Disk $DISK does not exist."
    fi
}

# Function to get user credentials
function get_user_credentials() {
    USERNAME=$(dialog --inputbox "Enter username:" 8 40 3>&1 1>&2 2>&3)
    if [ -z "$USERNAME" ]; then
        error_message "Username cannot be empty."
    fi

    PASSWORD=$(dialog --passwordbox "Enter password for user $USERNAME:" 8 40 3>&1 1>&2 2>&3)
    if [ -z "$PASSWORD" ]; then
        error_message "Password cannot be empty."
    fi

    ROOT_PASSWORD=$(dialog --passwordbox "Enter root password:" 8 40 3>&1 1>&2 2>&3)
    if [ -z "$ROOT_PASSWORD" ]; then
        error_message "Root password cannot be empty."
    fi
}

# Function to choose EFI partition for UEFI systems
function choose_efi_partition() {
    EFI_PARTITION=$(dialog --inputbox "Enter your EFI partition (e.g., /dev/sda1, leave blank for BIOS):" 8 40 3>&1 1>&2 2>&3)
}

# Function to choose GUI
function choose_gui() {
    GUI=$(dialog --menu "Choose a GUI to install:" 15 50 3 \
    1 "GNOME" \
    2 "KDE Plasma" \
    3 "Xfce" \
    3>&1 1>&2 2>&3)

    case $GUI in
        1)  # Install GNOME
            echo "Installing GNOME..."
            pacman -S --noconfirm gnome gnome-extra
            systemctl enable gdm.service
            ;;
        2)  # Install KDE Plasma
            echo "Installing KDE Plasma..."
            pacman -S --noconfirm plasma kde-applications
            systemctl enable sddm.service
            ;;
        3)  # Install Xfce
            echo "Installing Xfce..."
            pacman -S --noconfirm xfce4 xfce4-goodies
            systemctl enable lightdm.service
            ;;
        *)
            error_message "Invalid choice."
            ;;
    esac
}

# Get user inputs
get_hostname
choose_timezone
choose_disk
get_user_credentials

# Determine if the system is UEFI
if [[ "$DISK" == /dev/nvme* ]]; then
    choose_efi_partition
else
    EFI_PARTITION=""
fi

# Update the system clock
timedatectl set-ntp true

# Partition the disk (this will erase all data on the disk)
dialog --msgbox "Partitioning the disk $DISK. This will erase all data!" 6 60
parted $DISK mklabel gpt
parted $DISK mkpart primary ext4 1MiB 100%  # Create a single partition
parted $DISK set 1 boot on

# Format the partition
mkfs.ext4 ${DISK}1

# Mount the partition
mount ${DISK}1 /mnt

# Install base packages
pacstrap /mnt base linux linux-firmware vim

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set the timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Locale settings
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname

# Create a new user
useradd -m -G wheel $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Install and configure sudo
pacman -S --noconfirm sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install GRUB
pacman -S --noconfirm grub os-prober

# Install GRUB to the disk
if [ -n "$EFI_PARTITION" ]; then
    # For UEFI systems
    mkdir -p /boot/efi
    mount "$EFI_PARTITION" /boot/efi
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
    # For BIOS systems
    grub-install --target=i386-pc --boot-directory=/boot $DISK
fi

# Generate GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg

# Prompt user for GUI installation
choose_gui

# Exit chroot
EOF

# Unmount and reboot
umount -R /mnt
dialog --msgbox "Installation complete! You can now reboot." 6 60
