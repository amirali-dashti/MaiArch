#!/bin/bash

# Install dialog if not present
if ! command -v dialog &> /dev/null; then
    echo "Installing dialog package..."
    sudo pacman -Sy --noconfirm dialog
fi

LOG_FILE="/var/log/maiarch_install_cli_gui.log"  # Log file for installation process

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    dialog --title "Error" --msgbox "Please run this script as root." 6 40
    exit 1
fi

# Check for internet connectivity
if ! ping -c 1 google.com &>/dev/null; then
    dialog --title "Error" --msgbox "No internet connection detected. Please check your connection and try again." 6 50
    exit 1
fi

# Select disk for installation
DISK=$(lsblk -dpno NAME | dialog --title "Select Disk" --menu "Choose the disk to install MaiArch on:" 15 50 4 $(lsblk -dpno NAME) 3>&1 1>&2 2>&3)
if [ -z "$DISK" ]; then
    dialog --title "Error" --msgbox "Disk selection is required. Please rerun the script." 6 50
    exit 1
fi

# Partition disk using parted
dialog --title "Partitioning Disk" --msgbox "Partitioning the selected disk: $DISK" 6 50
parted "$DISK" --script mklabel gpt mkpart primary fat32 1MiB 514MiB mkpart primary ext4 514MiB 100% set 1 esp on

# Format partitions
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 "${DISK}2"

# Mount partitions
mount "${DISK}2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISK}1" /mnt/boot/efi

# Install base system
dialog --title "Installing Base System" --msgbox "Installing the base system. This may take some time." 6 60
pacstrap /mnt base base-devel linux linux-firmware

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configure hostname and timezone
HOSTNAME=$(dialog --title "Hostname" --inputbox "Enter the hostname for your MaiArch system:" 8 40 3>&1 1>&2 2>&3)
TIMEZONE=$(dialog --title "Timezone" --inputbox "Enter your timezone (e.g., America/New_York):" 8 40 3>&1 1>&2 2>&3)

# Check if hostname and timezone are provided
if [ -z "$HOSTNAME" ] || [ -z "$TIMEZONE" ]; then
    dialog --title "Error" --msgbox "Hostname and timezone must be provided. Please rerun the script." 6 50
    exit 1
fi

arch-chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
EOF

# Set root password
PASSWORD=$(dialog --title "Root Password" --insecure --passwordbox "Enter a password for the root user:" 8 40 3>&1 1>&2 2>&3)

# Check if password is provided
if [ -z "$PASSWORD" ]; then
    dialog --title "Error" --msgbox "Root password must be provided. Please rerun the script." 6 50
    exit 1
fi

arch-chroot /mnt /bin/bash <<EOF
echo "root:$PASSWORD" | chpasswd
EOF

# Install GUI (choose one)
GUI_CHOICE=$(dialog --title "Select GUI" --menu "Choose a Desktop Environment to install on MaiArch:" 15 40 3 \
  1 "GNOME" 2 "KDE" 3 "XFCE" 3>&1 1>&2 2>&3)

# Check if GUI choice is provided
if [ -z "$GUI_CHOICE" ]; then
    dialog --title "Error" --msgbox "GUI selection is required. Please rerun the script." 6 50
    exit 1
fi

arch-chroot /mnt /bin/bash <<EOF
case "$GUI_CHOICE" in
  1) pacman --noconfirm -S gnome gnome-extra gdm && systemctl enable gdm ;;
  2) pacman --noconfirm -S plasma kde-applications sddm && systemctl enable sddm ;;
  3) pacman --noconfirm -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter && systemctl enable lightdm ;;
esac
EOF

# Unmount partitions
umount -R /mnt

log "MaiArch installation complete."
dialog --title "Installation Complete" --msgbox "MaiArch installation complete! Please reboot your system." 8 40
