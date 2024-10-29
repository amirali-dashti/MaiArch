#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# Variables
HOSTNAME="archlinux"
TIMEZONE="UTC"
USERNAME="user"
PASSWORD="password" # Change this to a secure password
ROOT_PARTITION="/dev/sda1"
SWAP_PARTITION="/dev/sda2" # Optional, change if necessary
EFI_PARTITION="/dev/sda3" # For UEFI systems
MOUNT_POINT="/mnt"

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

# Install bootloader (for BIOS systems)
# grub-install --target=i386-pc /dev/sda

# Install bootloader (for UEFI systems)
grub-install --target=x86_64-efi --efi-directory=$EFI_PARTITION --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# Unmount partitions and reboot
umount -R $MOUNT_POINT
echo "Installation complete. You can now reboot."
