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

# Function to list available storage devices and prompt for selection
select_disk() {
    disk_options=()
    while IFS= read -r line; do
        disk_name=$(echo "$line" | awk '{print $1}')
        disk_size=$(echo "$line" | awk '{print $4}')
        disk_options+=("$disk_name" "$disk_size")
    done < <(lsblk -dpno NAME,SIZE | grep -E "/dev/sd|/dev/nvme|/dev/vd")
    DISK=$(dialog --title "Disk Selection" --menu "Choose the disk to install to:" 15 50 4 "${disk_options[@]}" 3>&1 1>&2 2>&3)
    
    if [ -z "$DISK" ]; then
        dialog --title "Error" --msgbox "No disk selected. Exiting..." 8 40
        exit 1
    fi
    dialog --title "Info" --msgbox "Selected disk: $DISK" 8 40
}

# Detect boot mode
BOOT_MODE=$(detect_boot_mode)
dialog --title "Info" --msgbox "$BOOT_MODE system detected." 8 40

# Check for internet connection
check_internet

# Call disk selection function
select_disk

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

## STAGE 2 : UPDATE MIRRORLIST WITH RETRIES AND FALLBACK ##

# Function to update mirrors with retry logic and fallback
update_mirrors() {
    local attempts=5       # Number of attempts for retries
    local wait_time=5      # Initial wait time between retries
    local success=false    # Track if update succeeds

    for ((i=1; i<=attempts; i++)); do
        echo "Attempt $i to update mirrors..."
        if reflector --latest 200 --protocol https --sort rate --save /etc/pacman.d/mirrorlist; then
            success=true
            dialog --title "Info" --msgbox "Mirror list updated successfully." 8 40
            break
        else
            echo "Mirror update failed. Retrying in $wait_time seconds..."
            sleep "$wait_time"
            wait_time=$((wait_time * 2))
        fi
    done

    if [ "$success" = false ]; then
        echo "Failed to update mirrors after $attempts attempts."
        echo "Using fallback mirror list."
        echo "Server = https://mirrors.edge.kernel.org/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
        dialog --title "Warning" --msgbox "Mirror list update failed. Using fallback mirror." 8 50
    fi
}

# Call the function to update mirrors
update_mirrors

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
