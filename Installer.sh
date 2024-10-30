#!/bin/bash

# Ensure script runs as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Install dialog if not installed
if ! command -v dialog &> /dev/null; then
  pacman -Sy --noconfirm dialog
fi

# Dialog function to gather user options
function get_user_options() {
  dialog --title "Arch Linux Installer" --msgbox "Welcome to the Arch Linux automated installer." 10 50
  dialog --title "Confirm Disk Wipe" \
    --yesno "This will delete all partitions on /dev/sda and install Arch Linux. Continue?" 10 50
  response=$?
  if [ $response -eq 1 ]; then
    clear
    echo "Installation canceled."
    exit 1
  fi

  dialog --title "Hostname" --inputbox "Enter a hostname for the system:" 10 50 2>hostname.txt
  HOSTNAME=$(<hostname.txt)
  rm hostname.txt

  dialog --title "Username" --inputbox "Enter a username for the new user:" 10 50 2>username.txt
  USERNAME=$(<username.txt)
  rm username.txt

  dialog --title "Password" --passwordbox "Enter a password for the user:" 10 50 2>password.txt
  PASSWORD=$(<password.txt)
  rm password.txt

  dialog --title "Root Password" --passwordbox "Enter a password for the root user:" 10 50 2>rootpass.txt
  ROOTPASS=$(<rootpass.txt)
  rm rootpass.txt
}

# Partitioning and formatting
function partition_disk() {
  dialog --title "Disk Partitioning" --msgbox "Partitioning and formatting /dev/sda..." 10 50
  (
    echo g          # Create a new GPT partition table
    echo n          # New partition for /boot
    echo            # Default partition number
    echo            # Default first sector
    echo +512M      # 512MB boot partition
    echo t          # Change partition type
    echo 1          # Select partition 1
    echo n          # New partition for root
    echo            # Default partition number
    echo            # Default first sector
    echo +20G       # 20GB root partition
    echo n          # New partition for home
    echo            # Default partition number
    echo            # Default first sector
    echo            # Use the remaining space
    echo w          # Write changes
  ) | fdisk /dev/sda

  mkfs.fat -F32 /dev/sda1
  mkfs.ext4 /dev/sda2
  mkfs.ext4 /dev/sda3
}

# Mount partitions and install base packages
function install_base_system() {
  mount /dev/sda2 /mnt
  mkdir /mnt/boot
  mount /dev/sda1 /mnt/boot
  mkdir /mnt/home
  mount /dev/sda3 /mnt/home

  pacstrap /mnt base linux linux-firmware nano sudo dialog
}

# Configuring the system
function configure_system() {
  genfstab -U /mnt >> /mnt/etc/fstab
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/$(curl -s https://ipinfo.io | jq -r .timezone) /etc/localtime
  arch-chroot /mnt hwclock --systohc
  arch-chroot /mnt echo "$HOSTNAME" > /etc/hostname
  arch-chroot /mnt echo "127.0.0.1   localhost" >> /etc/hosts
  arch-chroot /mnt echo "::1         localhost" >> /etc/hosts
  arch-chroot /mnt echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts
  arch-chroot /mnt sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  arch-chroot /mnt locale-gen
  arch-chroot /mnt echo "LANG=en_US.UTF-8" > /etc/locale.conf
}

# Set up user and root passwords, bootloader installation
function finalize_installation() {
  echo -e "$ROOTPASS\n$ROOTPASS" | arch-chroot /mnt passwd
  arch-chroot /mnt useradd -m -G wheel "$USERNAME"
  echo -e "$PASSWORD\n$PASSWORD" | arch-chroot /mnt passwd "$USERNAME"
  arch-chroot /mnt sed -i '/%wheel ALL=(ALL) ALL/s/^# //g' /etc/sudoers

  arch-chroot /mnt pacman -Sy --noconfirm grub
  arch-chroot /mnt grub-install --target=i386-pc /dev/sda
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

# Execute functions in sequence
get_user_options
partition_disk
install_base_system
configure_system
finalize_installation

# Wrap up
dialog --title "Installation Complete" --msgbox "Arch Linux installation is complete. You may reboot now." 10 50
umount -R /mnt
reboot
