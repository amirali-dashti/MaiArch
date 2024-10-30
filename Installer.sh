#!/bin/bash

# Check if dialog is installed
if ! command -v dialog &> /dev/null
then
    echo "dialog is not installed. Installing..."
    sudo pacman -S dialog
    exit 1
fi

# Welcome Dialog
dialog --title "Welcome to MaiArch Installation" \
       --msgbox "\nWARNING: THIS OS IS EARLY RELEASE AND IS NOT STABLE. PLEASE CONSIDER THIS!\nWelcome to the MaiArch Installer!\n\nThis installation will guide you through setting up MaiArch, your custom Arch-based system.\n\nFirst, we will use the official Arch Installer to perform the base installation, ensuring reliability and precision.\n\nFollowing that, MaiArchInstaller will handle essential configurations and add files tailored to your system." 15 50

# Proceed Confirmation
dialog --title "MaiArch Installation Confirmation" \
       --yesno "Are you ready to start the installation process?" 7 50
if [ $? -ne 0 ]; then
    dialog --msgbox "Installation canceled. You can restart the installation anytime." 5 40
    clear
    exit 1
fi

# Begin Arch Installation using Archinstall
dialog --title "Starting Arch Install" \
       --infobox "Starting the Arch Installer...\n\nThe system will proceed with the Arch base installation." 7 50
sleep 2  # Delay for user readability (optional)

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


if [ $? -ne 0 ]; then
    dialog --title "Installation Error" \
           --msgbox "The Arch installation encountered an error. Please review the logs and try again." 8 50
    clear
    exit 1
fi

# MaiArch Customization
dialog --title "MaiArch Customization" \
       --infobox "Proceeding with MaiArchInstaller for additional customization..." 5 50
sleep 2  # Delay for readability

# Run MaiArchInstaller (additional custom installation steps)
# Note: This is a placeholder. Replace with actual commands for MaiArch customization.
echo "Running MaiArchInstaller custom configurations..." # You can replace this with the actual command
# e.g., ./MaiArchInstaller.sh

dialog --title "Installation Complete" \
       --msgbox "Congratulations! MaiArch has been successfully installed and customized.\n\nPlease reboot your system to apply changes." 10 50

# End of script

umount -R /mnt
clear
