#!/bin/bash

# Synopsys: This file is intended to run on a LiveCD Arch Linux system
# and is designed to install a base system to a specified disk, along with
# necessary packages and configuration files.

# Proper usage to run this script:
# wget https://raw.githubusercontent.com/portalmaster137/ArchyBootstrapper/main/booter.sh | chmod +x booter.sh | ./booter.sh

# Function to display an error message and exit
error_exit() {
    dialog --msgbox "$1" 8 40
    exit 1
}

# Function to check if a command exists
check_command() {
    command -v "$1" &> /dev/null || error_exit "$1 is not installed. Please install it first."
}

# Check if dialog is installed
check_command dialog

## STAGE 1 : CONFIGURATION ##

# Determine if this is a UEFI or BIOS system
BIOS=False
UEFI=False
if [ -d "/sys/firmware/efi/efivars" ]; then
    [ $(cat /sys/firmware/efi/fw_platform_size) -eq 32 ] && error_exit "32-bit UEFI systems are not supported."
    UEFI=True
else
    BIOS=True
fi

# Check for internet connection
ping -c 1 google.com &> /dev/null || error_exit "No internet connection detected."

lsblk

# Prompt for installation disk
DISK=$(dialog --inputbox "Please enter the disk to install to (e.g., /dev/sda):" 8 40 3>&1 1>&2 2>&3)
[ ! -b "$DISK" ] && error_exit "$DISK is not a valid block device."

# Prompt for hostname
HOSTNAME=$(dialog --inputbox "Please enter the hostname of the system:" 8 40 "myarch" 3>&1 1>&2 2>&3)

# Prompt for username
USERNAME=$(dialog --inputbox "Please enter the username of the user account to be created:" 8 40 "user" 3>&1 1>&2 2>&3)

# Prompt for timezone with validation
while true; do
    dTIMEZONE=$(dialog --inputbox "Please enter your timezone (e.g., America/New_York):" 8 40 "America/New_York" 3>&1 1>&2 2>&3)
    [ -f "/usr/share/zoneinfo/$dTIMEZONE" ] && break
    dialog --msgbox "Invalid timezone. Please try again." 8 40
done
TIMEZONE=$dTIMEZONE

## STAGE 2 : PARTITIONING ##

# Confirm partitioning
dialog --yesno "The following disk will be partitioned: $DISK\nThis will erase all data on the disk.\nAre you sure you want to continue?" 8 60
[ $? -ne 0 ] && exit 1

# Check disk size
[ $(lsblk -b -n -o SIZE $DISK) -lt 15000000000 ] && error_exit "Disk $DISK is too small. It must be at least 15GB."

# Partition the disk
if [ "$BIOS" = True ]; then
    dialog --msgbox "Partitioning disk $DISK for BIOS system." 8 40
    parted -s $DISK mklabel msdos
    parted -s $DISK mkpart primary linux-swap 1MiB 513MiB
    parted -s $DISK mkpart primary ext4 513MiB 100%
    mkswap ${DISK}1
    mkfs.ext4 ${DISK}2
    mount ${DISK}2 /mnt
    swapon ${DISK}1
else
    dialog --msgbox "Partitioning disk $DISK for UEFI system." 8 40
    parted -s $DISK mklabel gpt
    parted -s $DISK mkpart primary fat32 1MiB 1025MiB
    parted -s $DISK mkpart primary linux-swap 1025MiB 1537MiB
    parted -s $DISK mkpart primary ext4 1537MiB 100%
    mkfs.fat -F 32 ${DISK}1
    mkswap ${DISK}2
    mkfs.ext4 ${DISK}3
    mount ${DISK}3 /mnt
    swapon ${DISK}2
    mount --mkdir ${DISK}1 /mnt/boot
fi

dialog --msgbox "Generating fstab." 8 40
genfstab -U /mnt >> /mnt/etc/fstab 

dialog --msgbox "Disk $DISK has been partitioned and mounted." 8 40

dialog --msgbox "Updating Mirrorlist." 8 40
reflector --latest 200 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 

## STAGE 3 : INSTALLATION ##
dialog --msgbox "Installing base system." 8 40
pacstrap -k /mnt base linux linux-firmware sof-firmware NetworkManager vim nano sudo grub efibootmgr elinks git reflector

dialog --msgbox "Base system installed." 8 40

## STAGE 4 : SYSTEM CONFIGURATION ##
dialog --msgbox "Doing final configuration." 8 40

arch-chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
systemctl enable NetworkManager
echo "root:root" | chpasswd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$USERNAME" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

dialog --msgbox "Final configuration complete." 8 40

umount -R /mnt

dialog --msgbox "Installation complete." 8 40
