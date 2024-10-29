#!/bin/bash

# Function to display error message and exit
error_exit() {
    dialog --msgbox "$1" 8 40
    exit 1
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error_exit "$1 is not installed. Please install it first."
    fi
}

# Check if dialog is installed, install if not
check_command dialog

# Step 1: Get User Input
HOSTNAME=$(dialog --inputbox "Enter the hostname for your system:" 8 40 myarch 3>&1 1>&2 2>&3 3>&-)
if [ -z "$HOSTNAME" ]; then
    error_exit "Hostname cannot be empty."
fi

USERNAME=$(dialog --inputbox "Enter your username:" 8 40 user 3>&1 1>&2 2>&3 3>&-)
if [ -z "$USERNAME" ]; then
    error_exit "Username cannot be empty."
fi

PASSWORD=$(dialog --inputbox "Enter your password:" 8 40 password 3>&1 1>&2 2>&3 3>&-)
if [ -z "$PASSWORD" ]; then
    error_exit "Password cannot be empty."
fi

ROOT_PASSWORD=$(dialog --inputbox "Enter root password:" 8 40 rootpassword 3>&1 1>&2 2>&3 3>&-)
if [ -z "$ROOT_PASSWORD" ]; then
    error_exit "Root password cannot be empty."
fi

# Step 2: Disk Selection
DISK=$(dialog --inputbox "Enter the disk you want to install Arch Linux on (e.g., /dev/sda):" 8 40 /dev/sdX 3>&1 1>&2 2>&3 3>&-)
if [ ! -b "$DISK" ]; then
    error_exit "$DISK is not a valid block device. Please check the disk name."
fi

# Step 3: Partition the Disk
dialog --msgbox "Please use a partitioning tool (like fdisk or cfdisk) to partition your disk. Once done, click OK." 8 60
dialog --msgbox "Ensure you create a root partition and a swap partition. After finishing, return here." 8 60

# Wait for user to finish partitioning
read -p "Press Enter once you have completed partitioning..."

# Step 4: Get Filesystem Type
FILESYSTEM=$(dialog --menu "Choose a filesystem for the root partition:" 15 50 4 \
    1 "ext4" \
    2 "btrfs" \
    3 "xfs" \
    4 "f2fs" 3>&1 1>&2 2>&3 3>&-)

# Step 5: Format Partitions
case $FILESYSTEM in
    1) mkfs.ext4 ${DISK}1 || error_exit "Failed to format ${DISK}1 with ext4." ;;
    2) mkfs.btrfs ${DISK}1 || error_exit "Failed to format ${DISK}1 with btrfs." ;;
    3) mkfs.xfs ${DISK}1 || error_exit "Failed to format ${DISK}1 with xfs." ;;
    4) mkfs.f2fs ${DISK}1 || error_exit "Failed to format ${DISK}1 with f2fs." ;;
    *) error_exit "Unsupported filesystem type!" ;;
esac

# Step 6: Create Swap
mkswap ${DISK}2 || error_exit "Failed to create swap on ${DISK}2."

# Step 7: Mount Filesystems
mount ${DISK}1 /mnt || error_exit "Failed to mount ${DISK}1."
swapon ${DISK}2 || error_exit "Failed to enable swap on ${DISK}2."

# Step 8: Install Base System
PACKAGES=$(dialog --inputbox "Enter additional packages to install (space-separated), or leave blank for defaults:" 8 60 "vim nano" 3>&1 1>&2 2>&3 3>&-)
DEFAULT_PACKAGES="base linux linux-firmware"
FULL_PACKAGE_LIST="$DEFAULT_PACKAGES $PACKAGES"

pacstrap /mnt $FULL_PACKAGE_LIST || error_exit "Failed to install base system."

# Step 9: Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab || error_exit "Failed to generate fstab."

# Step 10: Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Step 11: Set Time Zone
TIMEZONE=$(dialog --inputbox "Enter your time zone (e.g., America/New_York):" 8 60 "Region/City" 3>&1 1>&2 2>&3 3>&-)
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime || exit 1
hwclock --systohc || exit 1

# Step 12: Localization
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen || exit 1

# Step 13: Set Hostname
echo "$HOSTNAME" > /etc/hostname || exit 1
cat <<EOL >> /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain  $HOSTNAME
EOL

# Step 14: Create User
useradd -m -G wheel $USERNAME || exit 1
echo "$USERNAME:$PASSWORD" | chpasswd || exit 1
echo "root:$ROOT_PASSWORD" | chpasswd || exit 1
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers || exit 1

# Step 15: Install Bootloader
pacman -S --noconfirm grub || exit 1
grub-install --target=i386-pc $DISK || exit 1
grub-mkconfig -o /boot/grub/grub.cfg || exit 1

EOF

# Step 16: Unmount and Prompt to Reboot
umount -R /mnt || error_exit "Failed to unmount partitions."
dialog --msgbox "Installation is complete! Please reboot your system to start using Arch Linux." 8 60
echo "Installation completed successfully. You can reboot your system now."
