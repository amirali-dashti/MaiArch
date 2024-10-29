#!/bin/bash

# Synopsys: This script installs a base Arch Linux system on a specified disk.

# Proper usage: 
# wget https://raw.githubusercontent.com/portalmaster137/ArchyBootstrapper/main/booter.sh 
# chmod +x booter.sh 
# ./booter.sh

# Install dialog if not present
command -v dialog &> /dev/null || sudo pacman -Sy --noconfirm dialog

## STAGE 1 : CONFIGURATION ##

# Determine if the system is UEFI or BIOS.
BIOS=False
UEFI=False

if [ -d "/sys/firmware/efi/efivars" ]; then
    if [ "$(cat /sys/firmware/efi/fw_platform_size)" -eq 32 ]; then
        dialog --title "Error" --msgbox "32-bit UEFI systems are not supported by this installer. Exiting." 8 60
        exit 1
    fi
    UEFI=True
    dialog --title "Info" --msgbox "UEFI system detected." 8 40
else
    BIOS=True
    dialog --title "Info" --msgbox "BIOS system detected." 8 40
fi

# Check for internet connection.
if ! ping -c 1 google.com &> /dev/null; then
    dialog --title "Error" --msgbox "No internet connection detected. Please connect and try again." 8 60
    exit 1
fi

# Show available disks
lsblk

# Prompt for installation disk
DISK=$(dialog --title "Select Disk" --inputbox "Enter the disk to install to (e.g., /dev/sda, /dev/nvme0n1):" 8 60 3>&1 1>&2 2>&3)
if [ ! -b "$DISK" ]; then
    dialog --title "Error" --msgbox "Disk $DISK does not exist. Please rerun the script." 8 60
    exit 1
fi

# Prompt for hostname
HOSTNAME=$(dialog --title "Hostname" --inputbox "Enter the hostname of the system:" 8 40 3>&1 1>&2 2>&3)

# Prompt for username
USERNAME=$(dialog --title "Username" --inputbox "Enter the username of the user account to be created:" 8 40 3>&1 1>&2 2>&3)

# Prompt for timezone
TIMEZONE=""
until [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; do
    TIMEZONE=$(dialog --title "Timezone" --inputbox "Enter your timezone (e.g., America/New_York):" 8 40 3>&1 1>&2 2>&3)
done

## STAGE 2 : PARTITIONING ##

# Confirmation before partitioning
CONFIRM=$(dialog --title "Confirmation" --yesno "The following disk will be partitioned: $DISK\nThis will erase all data on the disk.\n\nAre you sure you want to continue?" 10 60)
if [ $? -ne 0 ]; then
    dialog --title "Aborted" --msgbox "Aborting." 6 30
    exit 1
fi

# Check disk size
if [ "$(lsblk -b -n -o SIZE "$DISK")" -lt 15000000000 ]; then
    dialog --title "Error" --msgbox "Disk $DISK is too small. It must be at least 15GB." 8 60
    exit 1
fi

# Partition the disk based on BIOS or UEFI
if [ "$BIOS" = True ]; then
    dialog --title "Info" --msgbox "Partitioning disk $DISK for BIOS system." 8 40
    parted -s "$DISK" mklabel msdos
    parted -s "$DISK" mkpart primary linux-swap 1MiB 513MiB
    parted -s "$DISK" mkpart primary ext4 513MiB 100%

    mkswap "${DISK}1"
    mkfs.ext4 "${DISK}2"

    mount "${DISK}2" /mnt
    swapon "${DISK}1"
else
    dialog --title "Info" --msgbox "Partitioning disk $DISK for UEFI system." 8 40
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart primary fat32 1MiB 1025MiB
    parted -s "$DISK" mkpart primary linux-swap 1025MiB 1537MiB
    parted -s "$DISK" mkpart primary ext4 1537MiB 100%

    mkfs.fat -F 32 "${DISK}1"
    mkswap "${DISK}2"
    mkfs.ext4 "${DISK}3"

    mount "${DISK}3" /mnt
    swapon "${DISK}2"
    mount --mkdir "${DISK}1" /mnt/boot
fi

dialog --title "Info" --msgbox "Generating fstab." 8 40
genfstab -U /mnt >> /mnt/etc/fstab

dialog --title "Info" --msgbox "Disk $DISK has been partitioned and mounted." 8 50

dialog --title "Info" --msgbox "Updating Mirrorlist." 8 40
reflector --latest 200 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 

## STAGE 3 : INSTALLATION ##
dialog --title "Info" --msgbox "Installing base system." 8 40
pacstrap -k /mnt base linux linux-firmware sof-firmware NetworkManager vim nano sudo grub efibootmgr elinks git reflector

dialog --title "Info" --msgbox "Base system installed." 8 40

## STAGE 4 : SYSTEM CONFIGURATION ##
dialog --title "Info" --msgbox "Performing final configuration." 8 40

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
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$USERNAME" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

dialog --title "Info" --msgbox "Final configuration complete." 8 40

umount -R /mnt

dialog --title "Installation Complete" --msgbox "Installation complete!" 8 40
