#!/bin/bash

# Install Zenity if not already installed
if ! command -v zenity &> /dev/null; then
    pacman -S --noconfirm zenity
fi

# Step 1: Get User Input
HOSTNAME=$(zenity --entry --title="Set Hostname" --text="Enter the hostname for your system:" --entry-text="myarch")
USERNAME=$(zenity --entry --title="Set Username" --text="Enter your username:" --entry-text="user")
PASSWORD=$(zenity --entry --title="Set Password" --text="Enter your password:" --entry-text="password" --hide-text)
ROOT_PASSWORD=$(zenity --entry --title="Set Root Password" --text="Enter root password:" --entry-text="rootpassword" --hide-text)

# Step 2: Disk Selection
DISK=$(zenity --entry --title="Disk Selection" --text="Enter the disk you want to install Arch Linux on (e.g., /dev/sda):" --entry-text="/dev/sdX")

# Step 3: Partition the Disk
zenity --info --text="Please use a partitioning tool (like fdisk or cfdisk) to partition your disk. Once done, click OK."
zenity --info --text="Ensure you create a root partition and a swap partition. After finishing, return here."

# Wait for user to finish partitioning
read -p "Press Enter once you have completed partitioning..."

# Step 4: Get Filesystem Type
FILESYSTEM=$(zenity --list --title="Select Filesystem Type" --column="Filesystem" --text="Choose a filesystem for the root partition:" --radiolist --column "Select" --column "Filesystem" TRUE "ext4" FALSE "btrfs" FALSE "xfs" FALSE "f2fs" FALSE "other")

# Step 5: Format Partitions
if [[ $FILESYSTEM == "ext4" ]]; then
    mkfs.ext4 ${DISK}1
elif [[ $FILESYSTEM == "btrfs" ]]; then
    mkfs.btrfs ${DISK}1
elif [[ $FILESYSTEM == "xfs" ]]; then
    mkfs.xfs ${DISK}1
elif [[ $FILESYSTEM == "f2fs" ]]; then
    mkfs.f2fs ${DISK}1
else
    zenity --error --text="Unsupported filesystem type!"
    exit 1
fi

# Step 6: Create Swap
mkswap ${DISK}2

# Step 7: Mount Filesystems
mount ${DISK}1 /mnt
swapon ${DISK}2

# Step 8: Install Base System
PACKAGES=$(zenity --entry --title="Package Selection" --text="Enter additional packages to install (space-separated), or leave blank for defaults:" --entry-text="vim nano")
DEFAULT_PACKAGES="base linux linux-firmware"
FULL_PACKAGE_LIST="$DEFAULT_PACKAGES $PACKAGES"

pacstrap /mnt $FULL_PACKAGE_LIST

# Step 9: Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Step 10: Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Step 11: Set Time Zone
TIMEZONE=$(zenity --entry --title="Set Time Zone" --text="Enter your time zone (e.g., America/New_York):" --entry-text="Region/City")
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
