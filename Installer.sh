#!/bin/bash

# Inform user about internet requirement
echo "This script requires internet connection for installation. Please ensure you have an active connection before proceeding."
read -p "Press Enter to continue or Ctrl+C to exit."

# Install dialog if not present
command -v dialog &> /dev/null || sudo pacman -Sy --noconfirm dialog

# Define log file path
LOG_FILE="/var/log/maiarch_install_cli_gui.log"

# Function to log messages with timestamp
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  log "Error: Please run this script with root privileges."
  dialog --title "Error" --msgbox "Please run as root." 6 40
  exit 1
fi

# Check for internet connectivity
ping -c 1 google.com &>/dev/null || {
  log "Error: No internet connection detected."
  dialog --title "Error" --msgbox "No internet connection detected." 6 40
  exit 1
}

# Select disk for installation
while true; do
  DISK=$(lsblk -dpno NAME | dialog --title "Select Disk" --menu "Choose the disk to install MaiArch on:" 15 50 4 $(lsblk -dpno NAME) 3>&1 1>&2 2>&3)
  [ -z "$DISK" ] && { dialog --title "Error" --msgbox "Disk selection required." 6 40; continue; }
  break;
done

# Partition disk using parted with error handling
log "Partitioning disk: $DISK"
parted "$DISK" --script mklabel gpt mkpart primary fat32 1MiB 514MiB mkpart primary ext4 514MiB 100% set 1 esp on || {
  log "Error: Failed to partition disk $DISK"
  exit 1
}

# Format partitions
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 "${DISK}2"

# Mount partitions
mount "${DISK}2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISK}1" /mnt/boot/efi

# Install base system
pacstrap /mnt base base-devel linux linux-firmware

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configure hostname and timezone
HOSTNAME=$(dialog --title "Hostname" --inputbox "Enter the hostname for your MaiArch system:" 8 40 3>&1 1>&2 2>&3)
TIMEZONE=$(dialog --title "Timezone" --inputbox "Enter your timezone (e.g., America/New_York):" 8 40 3>&1 1>&2 2>&3)

arch-chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
EOF

# Set root password securely (consider using a password manager for root)
read -s -p "Enter a password for the root user (characters won't be shown): " PASSWORD
echo "root:$PASSWORD" | chpasswd >/dev/null 2>&1

arch-chroot /mnt /bin/bash <<EOF
# ... same GUI installation section as before ...
esac
EOF

# Unmount partitions
umount -R /mnt

log "MaiArch installation complete."
dialog --title "Installation Complete" --msgbox "MaiArch installation complete! Please reboot your system." 8 40
