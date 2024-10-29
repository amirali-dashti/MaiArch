#!/bin/bash

# Synopsys: This script installs a base Arch Linux system on a specified disk.

# Proper usage: 
# wget https://raw.githubusercontent.com/portalmaster137/ArchyBootstrapper/main/booter.sh 
# chmod +x booter.sh 
# ./booter.sh

# Install necessary packages if not present
command -v dialog &> /dev/null || sudo pacman -Sy --noconfirm dialog
command -v curl &> /dev/null || sudo pacman -Sy --noconfirm curl
command -v rankmirrors &> /dev/null || sudo pacman -Sy --noconfirm pacman-contrib

# Clear the screen for a clean start
clear

## STAGE 1 : CONFIGURATION ##

# Function to detect BIOS/UEFI
detect_boot_mode() {
    if [ -d "/sys/firmware/efi/efivars" ]; then
        if [ "$(cat /sys/firmware/efi/fw_platform_size)" -eq 32 ]; then
            dialog --title "Error" --msgbox "32-bit UEFI systems are not supported by this installer.\nExiting..." 8 60
            exit 1
        fi
        echo "UEFI"
    else
        echo "BIOS"
    fi
}

# Check for internet connection
check_internet() {
    if ! ping -c 1 google.com &> /dev/null; then
        dialog --title "Error" --msgbox "No internet connection detected.\nPlease connect and try again." 8 60
        exit 1
    fi
}

# Function to prompt user input with dialog
get_input() {
    local title="$1"
    local prompt="$2"
    local default="$3"
    dialog --title "$title" --inputbox "$prompt" 8 60 "$default" 3>&1 1>&2 2>&3
}

# Detect boot mode
BOOT_MODE=$(detect_boot_mode)
dialog --title "Info" --msgbox "$BOOT_MODE system detected." 8 40

# Check for internet connection
check_internet

# Show available disks
lsblk | dialog --title "Available Disks" --textbox - 20 70

# Prompt for installation disk
DISK=$(get_input "Disk Selection" "Enter the disk to install to (e.g., /dev/sda):" "")
if [ ! -b "$DISK" ]; then
    dialog --title "Error" --msgbox "Disk $DISK does not exist.\nPlease rerun the script." 8 60
    exit 1
fi

# Prompt for hostname
HOSTNAME=$(get_input "Hostname" "Enter the hostname of the system:" "archlinux")

# Prompt for username
USERNAME=$(get_input "Username" "Enter the username of the user account to be created:" "user")

# Prompt for timezone
TIMEZONE=""
until [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; do
    TIMEZONE=$(get_input "Timezone" "Enter your timezone (e.g., America/New_York):" "")
done

## STAGE 2 : PARTITIONING ##

# Confirmation before partitioning
if ! dialog --title "Confirmation" --yesno "You are about to partition the disk: $DISK\nThis will erase all data on the disk.\n\nAre you sure you want to continue?" 10 60; then
    dialog --title "Aborted" --msgbox "Aborting the installation." 6 30
    exit 1
fi

# Check disk size
if [ "$(lsblk -b -n -o SIZE "$DISK")" -lt 15000000000 ]; then
    dialog --title "Error" --msgbox "Disk $DISK is too small. It must be at least 15GB." 8 60
    exit 1
fi

# Partition the disk based on BIOS or UEFI
if [ "$BOOT_MODE" = "BIOS" ]; then
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

dialog --title "Info" --msgbox "Generating fstab..." 8 40
genfstab -U /mnt >> /mnt/etc/fstab

dialog --title "Info" --msgbox "Disk $DISK has been successfully partitioned and mounted." 8 50

## STAGE 2 : UPDATE MIRRORLIST ##
dialog --title "Info" --msgbox "Updating Mirrorlist..." 8 40

# Backup existing mirrorlist
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

# Fetch the latest mirror list directly from the Arch Linux server
curl -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/ || {
    dialog --title "Error" --msgbox "Failed to fetch mirrorlist.\nPlease check your internet connection." 8 60
    exit 1
}

# Uncomment the server entries in the mirrorlist
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
# Sort the mirror list by speed
rankmirrors -n 6 /etc/pacman.d/mirrorlist | sudo tee /etc/pacman.d/mirrorlist > /dev/null

dialog --title "Info" --msgbox "Mirrorlist updated successfully." 8 40

## STAGE 3 : INSTALLATION ##
dialog --title "Info" --msgbox "Installing base system..." 8 40
if ! pacstrap -k /mnt base linux linux-firmware sof-firmware NetworkManager vim nano sudo grub efibootmgr elinks git; then
    dialog --title "Error" --msgbox "Base system installation failed.\nExiting..." 8 60
    exit 1
fi

dialog --title "Info" --msgbox "Base system installed successfully." 8 40

## STAGE 4 : SYSTEM CONFIGURATION ##
dialog --title "Info" --msgbox "Performing final configuration..." 8 40

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

# Unmount partitions
umount -R /mnt

dialog --title "Installation Complete" --msgbox "The installation is complete!\nPlease reboot your system." 8 50
