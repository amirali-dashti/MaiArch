#!/bin/bash

## STAGE 1 : CONFIGURATION ##

# Function to handle errors and exit
function handle_error {
    echo "Error: $1"
    exit 1
}

# Determine if the system is UEFI or BIOS.
BIOS=False
UEFI=False

if [ -d "/sys/firmware/efi/efivars" ]; then
    if [ "$(cat /sys/firmware/efi/fw_platform_size)" -eq 32 ]; then
        handle_error "32-bit UEFI systems are not supported by this installer."
    fi
    UEFI=True
    echo "UEFI system detected."
else
    BIOS=True
    echo "BIOS system detected."
fi

# Check for internet connection.
if ! ping -c 1 google.com &> /dev/null; then
    handle_error "No internet connection detected. Please connect and try again."
fi

# Show available disks
lsblk

# Prompt for installation disk
echo "Please enter the disk to install to (e.g., /dev/sda):"
read DISK

# Check if disk exists and has enough space
if [ ! -b "$DISK" ]; then
    handle_error "Disk $DISK does not exist."
fi

if [ "$(lsblk -b -n -o SIZE "$DISK")" -lt 15000000000 ]; then
    handle_error "Disk $DISK is too small. It must be at least 15GB."
fi

# Prompt for hostname
echo "Please enter the hostname of the system:"
read HOSTNAME

# Prompt for username
echo "Please enter the username of the user account to be created:"
read USERNAME

# Prompt for timezone
TIMEZONE=""
until [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; do
    echo "Please enter your timezone (e.g., America/New_York):"
    read dTIMEZONE
    TIMEZONE=$dTIMEZONE
done

## STAGE 2 : PARTITIONING ##

# Confirmation before partitioning
echo "You are about to partition the disk: $DISK. This will erase all data on the disk."
echo "Are you sure you want to continue? (y/n)"
read CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborting."
    exit 1
fi

# Partition the disk based on BIOS or UEFI
if [ "$BIOS" = True ]; then
    echo "Partitioning disk $DISK for BIOS system."
    parted -s "$DISK" mklabel msdos || handle_error "Failed to create partition table."
    parted -s "$DISK" mkpart primary linux-swap 1MiB 513MiB || handle_error "Failed to create swap partition."
    parted -s "$DISK" mkpart primary ext4 513MiB 100% || handle_error "Failed to create ext4 partition."

    mkswap "${DISK}1" || handle_error "Failed to format swap partition."
    mkfs.ext4 "${DISK}2" || handle_error "Failed to format ext4 partition."
    
    mount "${DISK}2" /mnt || handle_error "Failed to mount the ext4 partition."
    swapon "${DISK}1" || handle_error "Failed to enable swap."
    
else
    echo "Partitioning disk $DISK for UEFI system."
    parted -s "$DISK" mklabel gpt || handle_error "Failed to create partition table."
    parted -s "$DISK" mkpart primary fat32 1MiB 1025MiB || handle_error "Failed to create EFI partition."
    parted -s "$DISK" mkpart primary linux-swap 1025MiB 1537MiB || handle_error "Failed to create swap partition."
    parted -s "$DISK" mkpart primary ext4 1537MiB 100% || handle_error "Failed to create ext4 partition."

    mkfs.fat -F 32 "${DISK}1" || handle_error "Failed to format EFI partition."
    mkswap "${DISK}2" || handle_error "Failed to format swap partition."
    mkfs.ext4 "${DISK}3" || handle_error "Failed to format ext4 partition."

    mount "${DISK}3" /mnt || handle_error "Failed to mount the ext4 partition."
    swapon "${DISK}2" || handle_error "Failed to enable swap."
    mount --mkdir "${DISK}1" /mnt/boot || handle_error "Failed to mount the EFI partition."
fi

echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || handle_error "Failed to generate fstab."

echo "Disk $DISK has been partitioned and mounted."

echo "Updating Mirrorlist..."
reflector --latest 200 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || handle_error "Failed to update mirrorlist."

## STAGE 3 : INSTALLATION ##
echo "Installing base system..."
pacstrap -k /mnt base linux linux-firmware sof-firmware NetworkManager vim nano sudo grub efibootmgr elinks git reflector || handle_error "Failed to install base system."

echo "Base system installed."

## STAGE 4 : SYSTEM CONFIGURATION ##
echo "Doing final configuration..."

arch-chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen || exit 1
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
systemctl enable NetworkManager
echo "root:root" | chpasswd
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$USERNAME" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || exit 1
grub-mkconfig -o /boot/grub/grub.cfg || exit 1
EOF

echo "Final configuration complete."

umount -R /mnt || handle_error "Failed to unmount partitions."

echo "Installation complete! Please reboot your system."
