#!/bin/bash

LOG_FILE="/tmp/arch_install.log"

# Function to log messages
function log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  log "Please run as root."
  exit 1
fi

# Function to check for internet connectivity
function check_internet() {
  if ping -c 1 google.com &>/dev/null; then
    log "Internet connection detected."
  else
    log "No internet connection detected. Please check your network settings."
    exit 1
  fi
}

# Prompt for the disk device to use
read -p "Enter the disk to install Arch Linux on (e.g., /dev/sda): " DISK
if [[ -z "$DISK" ]]; then
  log "Disk input required."
  exit 1
fi

# Function to partition the disk
function partition_disk() {
  log "Partitioning the disk $DISK..."
  sgdisk --zap-all "$DISK" || { log "Failed to clear partitions."; exit 1; }
  sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:EFI "$DISK" || exit 1
  sgdisk --new=2:0:+512M --typecode=2:8300 --change-name=2:BOOT "$DISK" || exit 1
  sgdisk --new=3:0:0 --typecode=3:8300 --change-name=3:ROOT "$DISK" || exit 1
}

# Function to format the partitions
function format_partitions() {
  log "Formatting partitions..."
  mkfs.fat -F32 "${DISK}1" || { log "Failed to format EFI partition."; exit 1; }
  mkfs.ext4 "${DISK}2" || { log "Failed to format BOOT partition."; exit 1; }
  mkfs.ext4 "${DISK}3" || { log "Failed to format ROOT partition."; exit 1; }
}

# Function to mount the partitions
function mount_partitions() {
  log "Mounting partitions..."
  mount "${DISK}3" /mnt || { log "Failed to mount ROOT partition."; exit 1; }
  mkdir -p /mnt/boot /mnt/boot/efi
  mount "${DISK}2" /mnt/boot || { log "Failed to mount BOOT partition."; exit 1; }
  mount "${DISK}1" /mnt/boot/efi || { log "Failed to mount EFI partition."; exit 1; }
}

# Function to install the base system
function install_base_system() {
  log "Installing base system..."
  pacstrap /mnt base base-devel linux linux-firmware || { log "Base installation failed."; exit 1; }
}

# Function to generate the fstab file
function generate_fstab() {
  log "Generating fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab || { log "Failed to generate fstab."; exit 1; }
}

# Function to configure the system within chroot
function configure_system() {
  log "Configuring the system in chroot environment..."
  arch-chroot /mnt /bin/bash <<EOF

  # Prompt for hostname
  read -p "Enter hostname: " HOSTNAME
  echo "\$HOSTNAME" > /etc/hostname

  # Prompt for timezone
  read -p "Enter your timezone (e.g., 'America/New_York'): " TIMEZONE
  ln -sf "/usr/share/zoneinfo/\$TIMEZONE" /etc/localtime
  hwclock --systohc

  # Prompt for locale
  read -p "Enter your locale (e.g., 'en_US.UTF-8'): " LOCALE
  echo "LANG=\$LOCALE" > /etc/locale.conf
  echo "\$LOCALE UTF-8" >> /etc/locale.gen
  locale-gen

  # Prompt for root password
  echo "Enter a password for the root user:"
  passwd

  # Install and configure bootloader
  pacman --noconfirm -S grub efibootmgr
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg

  log "Configuration within chroot environment complete."
EOF
}

# Unmount partitions and provide completion message
function unmount_partitions() {
  log "Unmounting partitions..."
  umount -R /mnt || { log "Failed to unmount partitions."; exit 1; }
}

# Main script flow
log "Starting Arch Linux installation script..."
check_internet
partition_disk
format_partitions
mount_partitions
install_base_system
generate_fstab
configure_system
unmount_partitions
log "Arch Linux base installation complete. Please reboot."

# End of Script
