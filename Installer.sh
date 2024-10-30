#!/bin/bash

# Enforce Root Privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with root privileges (sudo)."
  exit 1
fi

# Check for dialog's existence (sonzai - existence)
if ! command -v dialog &> /dev/null; then
  echo "dialog is required for user interaction. Installing..."
  pacman -S --noconfirm dialog
fi

# Welcome Message
dialog --title "Welcome to MaiArch Installation" \
--msgbox "WARNING: THIS OS IS EARLY RELEASE AND UNSTABLE. USE WITH CAUTION!\nWelcome to the MaiArch Installer!" 15 50

# Confirmation Dialog
if ! dialog --title "MaiArch Installation Confirmation" --yesno "Are you ready to begin the installation process?" 7 50; then
  dialog --msgbox "Installation canceled. You can restart anytime." 5 40
  exit 1
fi

# User Input Functions
get_hostname() {
  local hostname=$(dialog --inputbox "Enter hostname:" 10 50 3>&1 1>&2 2>&3)
  if [ -z "$hostname" ]; then
    echo "Hostname cannot be empty."
    get_hostname
  else
    echo "$hostname"
  fi
}

get_username() {
  local username=$(dialog --inputbox "Enter username:" 10 50 3>&1 1>&2 2>&3)
  if [ -z "$username" ]; then
    echo "Username cannot be empty."
    get_username
  else
    echo "$username"
  fi
}

get_password() {
  local password=$(dialog --passwordbox "Enter password for user:" 10 50 3>&1 1>&2 2>&3)
  if [ -z "$password" ]; then
    echo "Password cannot be empty."
    get_password
  else
    echo "$password"
  fi
}

get_root_password() {
  local root_password=$(dialog --passwordbox "Enter password for root:" 10 50 3>&1 1>&2 2>&3)
  if [ -z "$root_password" ]; then
    echo "Root password cannot be empty."
    get_root_password
  else
    echo "$root_password"
  fi
}

# Gather User Input
hostname=$(get_hostname)
username=$(get_username)
user_password=$(get_password)
root_password=$(get_root_password)

# Disk Partitioning
(
  echo g                                   # New GPT partition table
  echo n                                   # Create /boot partition
  echo                                       # Default partition number
  echo                                       # Default first sector
  echo +512M                                # 512MB boot partition
  echo t                                   # Partition type
  echo 1                                   # EFI partition type for UEFI boot
  echo n                                   # Create root partition
  echo                                       # Default partition number
  echo                                       # Default first sector
  echo +20G                                 # 20GB root partition
  echo n                                   # Create home partition
  echo                                       # Default partition number
  echo                                       # Default first sector
  echo                                       # Use remaining space for home
  echo w                                   # Write changes
) | fdisk /dev/sda

if [ $? -ne 0 ]; then
  dialog --msgbox "Partitioning failed. Exiting..." 5 40
  exit 1
fi

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

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot Environment
arch-chroot /mnt /bin/bash <<EOF
# Set Timezone
ln -sf /usr/share/zoneinfo/$(curl -s https://ipinfo.io | jq -r .timezone) /etc/localtime
hwclock --systohc

# Configure System Hostname
echo "$hostname" > /etc/hostname

# Update Hosts File
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts

# Localization (en_US.UTF-8)
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set Root Password
echo -e "$root_password\n$root_password" | passwd

# Create User Account
useradd -m -G wheel "$username"
echo -e "$user_password\n$user_password" | passwd "$username"
sed -i '/%wheel ALL=(ALL) ALL/s/^\# //g' /etc/sudoers

# Bootloader Installation (GRUB)
if [ -d /sys/firmware/efi ]; then
  pacman -S --noconfirm grub efibootmgr
  mkdir -p /boot/efi
  mount /dev/sda1 /boot/efi
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
  pacman -S --noconfirm grub
  grub-install --target=i386-pc /dev/sda
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Driver Selection (Optional)
DRIVER_OPTIONS=("NetworkManager" "xf86-video-intel" "nvidia" "broadcom-wl" "linux-headers" "None")
CHOICES=$(dialog --checklist "Select Drivers to Install:" 15 60 6 \
                 1 "NetworkManager" off \
                 2 "xf86-video-intel" off \
                 3 "nvidia" off \
                 4 "broadcom-wl" off \
                 5 "linux-headers" off \
                 6 "None" off 3>&1 1>&2 2>&3)

if [ $? -eq 0 ]; then
  for DRIVER in $CHOICES; do
    case $DRIVER in
      1) pacman -S --noconfirm NetworkManager ;;
      2) pacman -S --noconfirm xf86-video-intel ;;
      3) pacman -S --noconfirm nvidia ;;
      4) pacman -S --noconfirm broadcom-wl ;;
      5) pacman -S --noconfirm linux-headers ;;
      6) echo "No drivers selected." ;;
    esac
  done
else
  dialog --msgbox "No drivers installed." 5 40
fi

# GUI Selection (Optional)
GUI_OPTIONS=("GNOME" "KDE" "XFCE" "LXQt" "None")
CHOICES_GUI=$(dialog --checklist "Select GUI Interfaces to Install:" 15 60 5 \
                  1 "GNOME" off \
                  2 "KDE" off \
                  3 "XFCE" off \
                  4 "LXQt" off \
                  5 "None" off 3>&1 1>&2 2>&3)

if [ $? -eq 0 ]; then
  for GUI in $CHOICES_GUI; do
    case $GUI in
      1) pacman -S --noconfirm gnome ;;
      2) pacman -S --noconfirm plasma ;;
      3) pacman -S --noconfirm xfce4 xfce4-goodies ;;
      4) pacman -S --noconfirm lxqt ;;
      5) echo "No GUI selected." ;;
    esac
  done
else
  dialog --msgbox "No GUI installed." 5 40
fi

EOF
# Exit Message
dialog --msgbox "Installation completed.\nThanks for choosing MaiArch!\nIf you found any problem/bug, please report it at https://www.github.com/devtracer/MaiArch\nThe system will get rebooted." 5 40
