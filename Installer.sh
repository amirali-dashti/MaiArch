#!/bin/bash

# Check if dialog is installed, install if not
if ! command -v dialog &> /dev/null; then
    pacman -S --noconfirm dialog
fi

# Step 1: Get User Input
HOSTNAME=$(dialog --inputbox "Enter the hostname for your system:" 8 40 myarch 3>&1 1>&2 2>&3 3>&-)
USERNAME=$(dialog --inputbox "Enter your username:" 8 40 user 3>&1 1>&2 2>&3 3>&-)
PASSWORD=$(dialog --inputbox "Enter your password:" 8 40 password 3>&1 1>&2 2>&3 3>&-)
ROOT_PASSWORD=$(dialog --inputbox "Enter root password:" 8 40 rootpassword 3>&1 1>&2 2>&3 3>&-)

# Step 2: Disk Selection
DISK=$(dialog --inputbox "Enter the disk you want to install Arch Linux on (e.g., /dev/sda):" 8 40 /dev/sdX 3>&1 1>&2 2>&3 3>&-)

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
if [[ $FILESYSTEM == "1" ]]; then
    mkfs.ext4 ${DISK}1
elif [[ $FILESYSTEM == "2" ]]; then
    mkfs.btrfs ${DISK}1
elif [[ $FILESYSTEM == "3" ]]; then
    mkfs.xfs ${DISK}1
elif [[ $FILESYSTEM == "4" ]]; then
    mkfs.f2fs ${DISK}1
else
    dialog --msgbox "Unsupported filesystem type!" 8 40
    exit 1
fi

# Step 6: Create Swap
mkswap ${DISK}2

# Step 7: Mount Filesystems
mount ${DISK}1 /mnt
swapon ${DISK}2

# Step 8: Install Base System
PACKAGES=$(dialog --inputbox "Enter additional packages to install (space-separated), or leave blank for defaults:" 8 60 "vim nano" 3>&1 1>&2 2>&3 3>&-)
DEFAULT_PACKAGES="base linux linux-firmware"
FULL_PACKAGE_LIST="$DEFAULT_PACKAGES $PACKAGES"

pacstrap /mnt $FULL_PACKAGE_LIST

# Step 9: Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Step 10: Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Step 11: Set Time Zone
TIMEZONE=$(dialog --inputbox "Enter your time zone (e.g., America/New_York):" 8 60 "Region/City" 3>&1 1>&2 2>&3 3>&-)
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Step 12: Localization
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

# Step 13: Set Hostname
echo "$HOSTNAME" > /etc/hostname
cat <<EOL >> /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain  $HOSTNAME
EOL

# Step 14: Create User
useradd -m -G wheel $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$ROOT_PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Step 15: Install Bootloader
pacman -S --noconfirm grub
grub-install --target=i386-pc $DISK
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# Step 16: Unmount and Reboot
umount -R /mnt
reboot
