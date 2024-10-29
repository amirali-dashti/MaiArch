#!/bin/bash

sudo pacman -S zenity


LOG_FILE="/tmp/arch_install_gui.log"

# Function to log messages
function log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  zenity --error --text="Please run as root."
  exit 1
fi

# Function to check for internet connectivity
function check_internet() {
  if ping -c 1 google.com &>/dev/null; then
    log "Internet connection detected."
  else
    zenity --error --text="No internet connection detected. Please check your network settings."
    exit 1
  fi
}

# Display available disks and prompt for selection
function select_disk() {
  DISK=$(lsblk -dpno NAME,SIZE | grep -E "/dev/sd|nvme|vd" | zenity --list --title="Select Disk" --text="Choose the disk to install Arch Linux on:" --column="Disk" --column="Size" --width=500 --height=300)
  if [[ -z "$DISK" ]]; then
    zenity --error --text="Disk selection required."
    exit 1
  fi
}

# Ask the user about partitioning preferences
function partition_disk() {
  CUSTOM_PARTITION=$(zenity --question --text="Do you want to create custom partitions?" --ok-label="Yes" --cancel-label="No"; echo $?)
  if [[ "$CUSTOM_PARTITION" -eq 0 ]]; then
    zenity --info --text="Please partition your disk manually, then press OK to continue."
    cfdisk "$DISK"
  else
    log "Creating default partitions on $DISK..."
    sgdisk --zap-all "$DISK"
    sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:EFI "$DISK"
    sgdisk --new=2:0:+512M --typecode=2:8300 --change-name=2:BOOT "$DISK"
    sgdisk --new=3:0:0 --typecode=3:8300 --change-name=3:ROOT "$DISK"
  fi
}

# Function to format partitions
function format_partitions() {
  log "Formatting partitions..."
  mkfs.fat -F32 "${DISK}1"
  mkfs.ext4 "${DISK}2"
  mkfs.ext4 "${DISK}3"
}

# Function to mount partitions
function mount_partitions() {
  log "Mounting partitions..."
  mount "${DISK}3" /mnt
  mkdir -p /mnt/boot /mnt/boot/efi
  mount "${DISK}2" /mnt/boot
  mount "${DISK}1" /mnt/boot/efi
}

# Function to install the base system
function install_base_system() {
  log "Installing base system..."
  pacstrap /mnt base base-devel linux linux-firmware
}

# Function to generate fstab
function generate_fstab() {
  log "Generating fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab
}

# Function to configure hostname, timezone, and locale
function configure_system() {
  HOSTNAME=$(zenity --entry --title="Hostname" --text="Enter the hostname:")
  TIMEZONE=$(zenity --entry --title="Timezone" --text="Enter your timezone (e.g., America/New_York):")
  LOCALE=$(zenity --entry --title="Locale" --text="Enter your locale (e.g., en_US.UTF-8):")

  arch-chroot /mnt /bin/bash <<EOF
  echo "$HOSTNAME" > /etc/hostname
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  hwclock --systohc
  echo "LANG=$LOCALE" > /etc/locale.conf
  echo "$LOCALE UTF-8" >> /etc/locale.gen
  locale-gen
EOF
}

# Function to set root password
function set_root_password() {
  PASSWORD=$(zenity --password --title="Root Password" --text="Enter a password for the root user:")
  arch-chroot /mnt /bin/bash <<EOF
  echo "root:$PASSWORD" | chpasswd
EOF
}

# Function to install GUI
function install_gui() {
  GUI_CHOICE=$(zenity --list --title="Select GUI" --text="Choose a Desktop Environment to install:" --radiolist --column="Select" --column="Environment" TRUE "GNOME" FALSE "KDE" FALSE "XFCE" --width=300 --height=250)

  arch-chroot /mnt /bin/bash <<EOF
  case "$GUI_CHOICE" in
    "GNOME")
      pacman --noconfirm -S gnome gnome-extra gdm
      systemctl enable gdm
      ;;
    "KDE")
      pacman --noconfirm -S plasma kde-applications sddm
      systemctl enable sddm
      ;;
    "XFCE")
      pacman --noconfirm -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
      systemctl enable lightdm
      ;;
    *)
      echo "No GUI selected."
      ;;
  esac
EOF
}

# Function to unmount partitions
function unmount_partitions() {
  log "Unmounting partitions..."
  umount -R /mnt
}

# Main script flow
log "Starting GUI-based Arch Linux installation script..."
check_internet
select_disk
partition_disk
format_partitions
mount_partitions
install_base_system
generate_fstab
configure_system
set_root_password
install_gui
unmount_partitions
log "Arch Linux installation complete. Please reboot."
zenity --info --text="Arch Linux installation complete! Please reboot your system."
