#!/bin/bash

# Log file for installation process
LOG_FILE="/var/log/maiarch_install_cli_gui.log"

# Install dialog if not present
if ! command -v dialog &> /dev/null; then
    echo "Dialog not found. Installing..."
    sudo pacman -Sy --noconfirm dialog
fi

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    dialog --title "Error" --msgbox "Please run as root." 6 40
    exit 1
fi

# Check for internet connectivity
if ! ping -c 1 google.com &> /dev/null; then
    dialog --title "Error" --msgbox "No internet connection detected." 6 40
    exit 1
fi

# Select disk for installation
DISK=$(lsblk -dpno NAME | dialog --title "Select Disk" --menu "Choose the disk to install MaiArch on:" 15 50 4 $(lsblk -dpno NAME) 3>&1 1>&2 2>&3)
if [ -z "$DISK" ]; then
    dialog --title "Error" --msgbox "Disk selection required." 6 40
    exit 1
fi

# Partition disk using parted
parted "$DISK" --script mklabel gpt mkpart primary fat32 1MiB 514MiB mkpart primary ext4 514MiB 100% set 1 esp on || {
    dialog --title "Error" --msgbox "Failed to partition the disk." 6 40
    exit 1
}

# Format partitions
mkfs.fat -F32 "${DISK}1" || { dialog --title "Error" --msgbox "Failed to format FAT32 partition." 6 40; exit 1; }
mkfs.ext4 "${DISK}2" || { dialog --title "Error" --msgbox "Failed to format ext4 partition." 6 40; exit 1; }

# Mount partitions
mount "${DISK}2" /mnt || { dialog --title "Error" --msgbox "Failed to mount ext4 partition." 6 40; exit 1; }
mkdir -p /mnt/boot/efi
mount "${DISK}1" /mnt/boot/efi || { dialog --title "Error" --msgbox "Failed to mount FAT32 partition." 6 40; exit 1; }

# Install base system
pacstrap /mnt base base-devel linux linux-firmware || {
    dialog --title "Error" --msgbox "Failed to install base system." 6 40
    exit 1
}

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configure hostname and timezone
HOSTNAME=$(dialog --title "Hostname" --inputbox "Enter the hostname for your MaiArch system:" 8 40 3>&1 1>&2 2>&3)
TIMEZONE=$(dialog --title "Timezone" --inputbox "Enter your timezone (e.g., America/New_York):" 8 40 3>&1 1>&2 2>&3)

# Update configuration in chroot
arch-chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
EOF

# Set root password
PASSWORD=$(dialog --title "Root Password" --insecure --passwordbox "Enter a password for the root user:" 8 40 3>&1 1>&2 2>&3)
arch-chroot /mnt /bin/bash <<EOF
echo "root:$PASSWORD" | chpasswd
EOF

# Install GUI (choose one)
GUI_CHOICE=$(dialog --title "Select GUI" --menu "Choose a Desktop Environment to install on MaiArch:" 15 40 3 \
  1 "GNOME" 2 "KDE" 3 "XFCE" 3>&1 1>&2 2>&3)

arch-chroot /mnt /bin/bash <<EOF
case "$GUI_CHOICE" in
  1) pacman --noconfirm -S gnome gnome-extra gdm && systemctl enable gdm ;;
  2) pacman --noconfirm -S plasma kde-applications sddm && systemctl enable sddm ;;
  3) pacman --noconfirm -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter && systemctl enable lightdm ;;
  *) echo "Invalid selection." ;;
esac
EOF

# Unmount partitions
umount -R /mnt || { dialog --title "Error" --msgbox "Failed to unmount partitions." 6 40; exit 1; }

# Log completion
log "MaiArch installation complete."
dialog --title "Installation Complete" --msgbox "MaiArch installation complete! Please reboot your system." 8 40
