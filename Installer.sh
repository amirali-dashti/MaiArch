#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Install dialog if not installed
if ! command -v dialog &> /dev/null; then
  pacman -Sy --noconfirm dialog
fi

# Get User Inputs
dialog --title "Arch Linux Installer" --msgbox "Welcome to Arch Linux automated installer." 10 50
dialog --title "Confirm Installation" \
       --yesno "This will delete all partitions on /dev/sda and install Arch Linux. Continue?" 10 50 || exit 1

# Collect Hostname, Username, and Passwords
dialog --inputbox "Enter hostname:" 10 50 2>hostname.txt
HOSTNAME=$(<hostname.txt)
rm hostname.txt

dialog --inputbox "Enter username:" 10 50 2>username.txt
USERNAME=$(<username.txt)
rm username.txt

dialog --passwordbox "Enter password for user:" 10 50 2>password.txt
PASSWORD=$(<password.txt)
rm password.txt

dialog --passwordbox "Enter password for root:" 10 50 2>rootpass.txt
ROOTPASS=$(<rootpass.txt)
rm rootpass.txt

# Disk Partitioning
(
  echo g              # New GPT partition table
  echo n              # Create /boot partition
  echo                # Default partition number
  echo                # Default first sector
  echo +512M          # 512MB boot partition
  echo t              # Partition type
  echo 1              # EFI partition type for UEFI boot
  echo n              # Create root partition
  echo                # Default partition number
  echo                # Default first sector
  echo +20G           # 20GB root partition
  echo n              # Create home partition
  echo                # Default partition number
  echo                # Default first sector
  echo                # Use remaining space for home
  echo w              # Write changes
) | fdisk /dev/sda

# Format Partitions
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mkfs.ext4 /dev/sda3

# Mount Partitions
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir /mnt/home
mount /dev/sda3 /mnt/home

# Base Installation
pacstrap /mnt base linux linux-firmware nano dialog

# Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and Configuration
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$(curl -s https://ipinfo.io | jq -r .timezone) /etc/localtime
hwclock --systohc
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Localization
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Network Configuration
echo "$HOSTNAME" > /etc/hostname

# Root Password
echo -e "$ROOTPASS\n$ROOTPASS" | passwd

# Add User
useradd -m -G wheel "$USERNAME"
echo -e "$PASSWORD\n$PASSWORD" | passwd "$USERNAME"
sed -i '/%wheel ALL=(ALL) ALL/s/^# //g' /etc/sudoers
EOF

# Bootloader Installation
if [ -d /sys/firmware/efi ]; then
  # UEFI mode
  arch-chroot /mnt pacman -S --noconfirm grub efibootmgr
  arch-chroot /mnt mkdir -p /boot/efi
  arch-chroot /mnt mount /dev/sda1 /boot/efi
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
  # BIOS mode
  arch-chroot /mnt pacman -S --noconfirm grub
  arch-chroot /mnt grub-install --target=i386-pc /dev/sda
fi
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Finish Up
dialog --title "Installation Complete" --msgbox "Installation finished! You can now reboot." 10 50
umount -R /mnt
reboot
