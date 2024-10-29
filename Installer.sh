#!/bin/bash

# Synopsis: This script installs a base Arch Linux system to a specified disk.
# Proper usage: wget https://raw.githubusercontent.com/portalmaster137/ArchyBootstrapper/main/booter.sh -O booter.sh && chmod +x booter.sh && ./booter.sh

## STAGE 1: CONFIGURATION ##

# Determine if this is a UEFI or BIOS system
BIOS=false
UEFI=false

if [ -d "/sys/firmware/efi/efivars" ]; then
    if [ "$(cat /sys/firmware/efi/fw_platform_size)" -eq 32 ]; then
        dialog --msgbox "32-bit UEFI systems are not supported. Exiting." 10 50
        exit 1
    fi
    UEFI=true
    dialog --infobox "UEFI system detected." 5 30
else
    BIOS=true
    dialog --infobox "BIOS system detected." 5 30
fi

# Check for internet connection
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    dialog --msgbox "No internet connection detected. Please set up your connection with iwctl or mmcli, then try again." 12 70
    exit 1
fi

# List available disks
lsblk | dialog --textbox - 20 70

# Prompt user for installation parameters using dialog
DISK=$(dialog --inputbox "Enter the disk to install to (e.g., /dev/sda, /dev/nvme0n1):" 8 60 3>&1 1>&2 2>&3 3>&-)
HOSTNAME=$(dialog --inputbox "Enter the hostname of the system:" 8 60 3>&1 1>&2 2>&3 3>&-)
USERNAME=$(dialog --inputbox "Enter the username for the user account to be created:" 8 60 3>&1 1>&2 2>&3 3>&-)

# Prompt for timezone until valid
TIMEZONE=""
while true; do
    TIMEZONE=$(dialog --inputbox "Enter your timezone (e.g., America/New_York):" 8 60 3>&1 1>&2 2>&3 3>&-)
    if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
        break
    fi
    dialog --msgbox "Invalid timezone. Please try again." 5 30
done

## STAGE 2: PARTITIONING ##

# Confirm partitioning
if ! dialog --yesno "The following disk will be partitioned: $DISK\nThis will erase all data on the disk.\nAre you sure you want to continue?" 10 70; then
    dialog --msgbox "Aborting." 5 30
    exit 1
fi

# Validate disk existence and size
if [ ! -b "$DISK" ]; then
    dialog --msgbox "Disk $DISK does not exist." 5 30
    exit 1
fi

if [ "$(blockdev --getsize64 "$DISK")" -lt 15000000000 ]; then
    dialog --msgbox "Disk $DISK is too small. It must be at least 15GB." 8 50
    exit 1
fi

# Partition the disk
if [ "$BIOS" = true ]; then
    dialog --infobox "Partitioning disk $DISK for BIOS system." 5 50
    parted "$DISK" mklabel msdos
    parted "$DISK" mkpart primary linux-swap 1MiB 513MiB
    parted "$DISK" mkpart primary ext4 513MiB 100% || exit 1

    # Format partitions
    mkswap "${DISK}1" || exit 1
    mkfs.ext4 "${DISK}2" || exit 1

    # Mount partitions
    mount "${DISK}2" /mnt || exit 1
    swapon "${DISK}1" || exit 1

else
    dialog --infobox "Partitioning disk $DISK for UEFI system." 5 50
    parted "$DISK" mklabel gpt
    parted "$DISK" mkpart primary fat32 1MiB 1025MiB
    parted "$DISK" mkpart primary linux-swap 1025MiB 1537MiB
    parted "$DISK" mkpart primary ext4 1537MiB 100% || exit 1

    # Format partitions
    mkfs.fat -F 32 "${DISK}1" || exit 1
    mkswap "${DISK}2" || exit 1
    mkfs.ext4 "${DISK}3" || exit 1

    # Mount partitions
    mount "${DISK}3" /mnt || exit 1
    swapon "${DISK}2" || exit 1
    mkdir -p /mnt/boot
    mount "${DISK}1" /mnt/boot || exit 1
fi

# Generate fstab
dialog --infobox "Generating fstab." 5 30
genfstab -U /mnt >> /mnt/etc/fstab

# Update mirrorlist
dialog --infobox "Updating mirrorlist." 5 30
reflector --latest 200 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 

## STAGE 3: INSTALLATION ##
dialog --infobox "Installing base system." 5 30
pacstrap -k /mnt base linux linux-firmware sof-firmware networkmanager vim nano sudo grub efibootmgr elinks git reflector

dialog --infobox "Base system installed." 5 30

## STAGE 4: SYSTEM CONFIGURATION ##
dialog --infobox "Doing final configuration." 5 30
arch-chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
systemctl enable NetworkManager

# Set root password
ROOT_PASSWORD=$(dialog --inputbox "Please enter the root password:" 10 50 3>&1 1>&2 2>&3 3>&-)
echo "root:$ROOT_PASSWORD" | chpasswd

# Create user and set password
useradd -m -G wheel -s /bin/bash "$USERNAME"
USER_PASSWORD=$(dialog --inputbox "Please enter the password for user $USERNAME:" 10 50 3>&1 1>&2 2>&3 3>&-)
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install GRUB
if [ "$UEFI" = true ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || exit 1
else
    grub-install --target=i386-pc "$DISK" || exit 1
fi

grub-mkconfig -o /boot/grub/grub.cfg || exit 1
EOF

dialog --msgbox "Final configuration complete." 8 40

# Unmount partitions
umount -R /mnt

dialog --msgbox "Installation complete." 6 30
