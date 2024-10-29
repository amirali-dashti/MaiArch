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

# Step 3: Choose Partitioning Method
PARTITION_METHOD=$(dialog --menu "Choose how to partition the disk:" 15 50 2 \
    1 "Manual Partitioning (Use fdisk/cfdisk)" \
    2 "Automated Partitioning (Erase and use defaults)" 3>&1 1>&2 2>&3 3>&-)

# Step 4: Partition the Disk
if [ "$PARTITION_METHOD" -eq 1 ]; then
    dialog --msgbox "Please use a partitioning tool (like fdisk or cfdisk) to partition your disk. Once done, click OK." 8 60
    dialog --msgbox "Ensure you create a root partition and a swap partition. After finishing, return here." 8 60
    read -p "Press Enter once you have completed partitioning..."
else
    dialog --msgbox "Automated partitioning will erase all data on ${DISK}. Proceed with caution!" 8 60
    sleep 2

    # Automated partitioning (example: using sgdisk)
    echo -e "o\nY\nn\n1\n\n+20G\n83\nn\n2\n\n\n82\nw\nY" | sgdisk --batch - "${DISK}" || error_exit "Automated partitioning failed."

    # Format the partitions
    mkfs.ext4 ${DISK}1 || error_exit "Failed to format ${DISK}1 with ext4."
    mkswap ${DISK}2 || error_exit "Failed to create swap on ${DISK}2."
fi

# Step 5: Mount Filesystems
mount ${DISK}1 /mnt || error_exit "Failed to mount ${DISK}1."
swapon ${DISK}2 || error_exit "Failed to enable swap on ${DISK}2."

# Step 6: Install Base System
PACKAGES=$(dialog --inputbox "Enter additional packages to install (space-separated), or leave blank for defaults:" 8 60 "vim nano" 3>&1 1>&2 2>&3 3>&-)
DEFAULT_PACKAGES="base linux linux-firmware"
FULL_PACKAGE_LIST="$DEFAULT_PACKAGES $PACKAGES"

pacstrap /mnt $FULL_PACKAGE_LIST || error_exit "Failed to install base system."

# Step 7: Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab || error_exit "Failed to generate fstab."

# Step 8: Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Step 9: Set Time Zone
TIMEZONE=$(dialog --inputbox "Enter your time zone (e.g., America/New_York):" 8 60 "Region/City" 3>&1 1>&2 2>&3 3>&-)
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime || exit 1
hwclock --systohc || exit 1

# Step 10: Localization
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen || exit 1

# Step 11: Set Hostname
echo "$HOSTNAME" > /etc/hostname || exit 1
cat <<EOL >> /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain  $HOSTNAME
EOL

# Step 12: Create User
useradd -m -G wheel $USERNAME || exit 1
echo "$USERNAME:$PASSWORD" | chpasswd || exit 1
echo "root:$ROOT_PASSWORD" | chpasswd || exit 1
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers || exit 1

# Step 13: Install Bootloader
pacman -S --noconfirm grub || exit 1
grub-install --target=i386-pc $DISK || exit 1
grub-mkconfig -o /boot/grub/grub.cfg || exit 1

EOF

# Step 14: Unmount and Prompt to Reboot
umount -R /mnt || error_exit "Failed to unmount partitions."
dialog --msgbox "Installation is complete! Please reboot your system to start using Arch Linux." 8 60
echo "Installation completed successfully. You can reboot your system now."
