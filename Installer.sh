#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# Function to list available disks
list_disks() {
    echo "Available disks:"
    lsblk -d -n -p | awk '{print $1, $2}'
}

# Function to create partitions
create_partitions() {
    local disk="$1"

    # Create partitions: Root (50G), Swap (8G), and EFI (200M)
    echo "Creating partitions on $disk..."

    # Clear the disk (optional, uncomment if needed)
    # wipefs -a "$disk"

    # Create partitions using fdisk
    (
        echo g # Create a new GPT partition table
        echo n # New partition for root
        echo 1 # Partition number 1
        echo   # Default first sector
        echo +50G # Size of root partition
        echo n # New partition for swap
        echo 2 # Partition number 2
        echo   # Default first sector
        echo +8G # Size of swap partition
        echo n # New partition for EFI
        echo 3 # Partition number 3
        echo   # Default first sector
        echo +200M # Size of EFI partition
        echo t # Change partition type
        echo 2 # Partition number 2 (swap)
        echo 19 # Linux swap
        echo t # Change partition type
        echo 3 # Partition number 3 (EFI)
        echo 1 # EFI System
        echo w # Write changes
    ) | fdisk "$disk"

    # Format the partitions
    mkfs.ext4 "${disk}1" # Root partition
    mkswap "${disk}2" # Swap partition
    mkfs.fat -F32 "${disk}3" # EFI partition

    # Enable swap
    swapon "${disk}2"
}

# Variables
HOSTNAME="archlinux"
TIMEZONE="UTC"
USERNAME="user"
PASSWORD="password" # Change this to a secure password
MOUNT_POINT="/mnt"

# List available disks
list_disks
echo
read -p "Enter the disk to install Arch Linux (e.g., /dev/sda): " SELECTED_DISK

# Create partitions
create_partitions "$SELECTED_DISK"

# Mount the root partition
mount "${SELECTED_DISK}1" "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT/boot/efi"
mount "${SELECTED_DISK}3" "$MOUNT_POINT/boot/efi"

# Install necessary packages
pacstrap $MOUNT_POINT base linux linux-firmware vim

# Generate fstab
genfstab -U $MOUNT_POINT >> $MOUNT_POINT/etc/fstab

# Chroot into the new system
arch-chroot $MOUNT_POINT /bin/bash << EOF
# Set the timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set the hostname
echo $HOSTNAME > /etc/hostname

# Set locale (uncomment your locale)
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set up the root password
echo "Set root password:"
passwd

# Create a new user
useradd -m -G wheel $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Configure sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install bootloader (for UEFI systems)
grub-install --target=x86_64-efi --efi-directory=$MOUNT_POINT/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# Unmount partitions and reboot
umount -R $MOUNT_POINT
echo "Installation complete. You can now reboot."
