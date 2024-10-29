#!/bin/bash

# Install dialog if not present
if ! command -v dialog &> /dev/null; then
  echo "Installing dialog for CLI-based GUI..."
  sudo pacman -Sy --noconfirm dialog
fi

LOG_FILE="/var/log/arch_install_cli_gui.log"
ROLLBACK_STACK=()

# Function to log messages
function log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Root check
if [ "$EUID" -ne 0 ]; then
  dialog --title "Error" --msgbox "Please run as root." 6 40
  exit 1
fi

# Rollback function to undo mounted directories and any setup steps
function rollback() {
  log "Starting rollback due to an error..."
  for action in "${ROLLBACK_STACK[@]}"; do
    eval "$action" && log "Rolled back: $action"
  done
  dialog --title "Installation Error" --msgbox "Installation failed. Rolled back changes. Please check the log at $LOG_FILE." 10 50
  exit 1
}

# Check for internet connectivity
function check_internet() {
  if ping -c 1 google.com &>/dev/null; then
    log "Internet connection detected."
  else
    dialog --title "Error" --msgbox "No internet connection detected. Please check your network settings." 8 60
    exit 1
  fi
}

# Select disk for installation
function select_disk() {
  DISK=$(lsblk -dpno NAME,SIZE | grep -E "/dev/sd|nvme|vd" | dialog --title "Select Disk" --menu "Choose the disk to install Arch Linux on:" 15 50 4 $(awk '{print $1 " \"" $2 "\""}') 3>&1 1>&2 2>&3)
  if [[ -z "$DISK" ]]; then
    dialog --title "Error" --msgbox "Disk selection required." 6 40
    exit 1
  fi
}

# Partition disk
function partition_disk() {
  dialog --title "Partitioning" --yesno "Do you want to create custom partitions?" 7 40
  if [[ $? -eq 0 ]]; then
    dialog --title "Partitioning" --msgbox "Please partition your disk manually, then press OK to continue." 8 40
    cfdisk "$DISK"
  else
    log "Creating default partitions on $DISK..."
    sgdisk --zap-all "$DISK"
    sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:EFI "$DISK"
    sgdisk --new=2:0:+512M --typecode=2:8300 --change-name=2:BOOT "$DISK"
    sgdisk --new=3:0:0 --typecode=3:8300 --change-name=3:ROOT "$DISK"
  fi
}

# Format partitions with validation and rollback on failure
function format_partitions() {
  log "Formatting partitions..."
  mkfs.fat -F32 "${DISK}1" && log "EFI partition formatted successfully." || rollback
  mkfs.ext4 "${DISK}2" && log "BOOT partition formatted successfully." || rollback
  mkfs.ext4 "${DISK}3" && log "ROOT partition formatted successfully." || rollback
}

# Mount partitions with rollback tracking
function mount_partitions() {
  log "Mounting partitions..."
  mount "${DISK}3" /mnt && ROLLBACK_STACK+=("umount /mnt") || rollback
  mkdir -p /mnt/boot /mnt/boot/efi
  mount "${DISK}2" /mnt/boot && ROLLBACK_STACK+=("umount /mnt/boot") || rollback
  mount "${DISK}1" /mnt/boot/efi && ROLLBACK_STACK+=("umount /mnt/boot/efi") || rollback
}

# Install base system with rollback if fails
function install_base_system() {
  log "Installing base system..."
  pacstrap /mnt base base-devel linux linux-firmware || rollback
}

# Generate fstab with validation
function generate_fstab() {
  log "Generating fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab
  if [[ $? -ne 0 ]]; then
    log "fstab generation failed!"
    rollback
  fi
}

# Validate user input to ensure it is not empty
function validate_input() {
  local input="$1"
  while [[ -z "$input" ]]; do
    input=$(dialog --title "Invalid Input" --inputbox "This field is required. Please enter a valid input:" 8 40 3>&1 1>&2 2>&3)
  done
  echo "$input"
}

# Configure hostname, timezone, and locale with validation
function configure_system() {
  HOSTNAME=$(dialog --title "Hostname" --inputbox "Enter the hostname:" 8 40 3>&1 1>&2 2>&3)
  HOSTNAME=$(validate_input "$HOSTNAME")

  TIMEZONE=$(dialog --title "Timezone" --inputbox "Enter your timezone (e.g., America/New_York):" 8 40 3>&1 1>&2 2>&3)
  TIMEZONE=$(validate_input "$TIMEZONE")

  LOCALE=$(dialog --title "Locale" --inputbox "Enter your locale (e.g., en_US.UTF-8):" 8 40 3>&1 1>&2 2>&3)
  LOCALE=$(validate_input "$LOCALE")

  arch-chroot /mnt /bin/bash <<EOF
  echo "$HOSTNAME" > /etc/hostname
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  hwclock --systohc
  echo "LANG=$LOCALE" > /etc/locale.conf
  echo "$LOCALE UTF-8" >> /etc/locale.gen
  locale-gen
EOF

  # Verify system configuration files
  if [[ ! -f /mnt/etc/hostname || ! -f /mnt/etc/locale.conf ]]; then
    log "Error in system configuration. Required configuration files not created!"
    rollback
  fi
}

# Set root password with validation
function set_root_password() {
  PASSWORD=$(dialog --title "Root Password" --insecure --passwordbox "Enter a password for the root user:" 8 40 3>&1 1>&2 2>&3)
  PASSWORD=$(validate_input "$PASSWORD")

  arch-chroot /mnt /bin/bash <<EOF
  echo "root:$PASSWORD" | chpasswd
EOF
  if [[ $? -ne 0 ]]; then
    log "Error setting root password!"
    rollback
  fi
}

# Install GUI with rollback tracking
function install_gui() {
  GUI_CHOICE=$(dialog --title "Select GUI" --menu "Choose a Desktop Environment to install:" 15 40 3 \
    1 "GNOME" 2 "KDE" 3 "XFCE" 3>&1 1>&2 2>&3)

  arch-chroot /mnt /bin/bash <<EOF
  case "$GUI_CHOICE" in
    1)
      pacman --noconfirm -S gnome gnome-extra gdm
      systemctl enable gdm
      ;;
    2)
      pacman --noconfirm -S plasma kde-applications sddm
      systemctl enable sddm
      ;;
    3)
      pacman --noconfirm -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
      systemctl enable lightdm
      ;;
  esac
EOF

  if [[ $? -ne 0 ]]; then
    log "Error installing GUI components!"
    rollback
  fi
}

# Unmount partitions
function unmount_partitions() {
  log "Unmounting partitions..."
  umount -R /mnt
}

# Main script flow
log "Starting CLI-based Arch Linux installation script..."
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
dialog --title "Installation Complete" --msgbox "Arch Linux installation complete! Please reboot your system." 8 40
