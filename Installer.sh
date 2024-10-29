#!/bin/bash

# Install dialog if not present
if ! command -v dialog &> /dev/null; then
  echo "Installing dialog for CLI-based interface..."
  sudo pacman -Sy --noconfirm dialog
fi

LOG_FILE="/var/log/maiarch_install_cli_gui.log"  # Log file for installation process
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
  DISK=$(lsblk -dpno NAME,SIZE | grep -E "/dev/sd|nvme|vd" | dialog --title "Select Disk" --menu "Choose the disk to install MaiArch on:" 15 50 4 $(awk '{print $1 " \"" $2 "\""}') 3>&1 1>&2 2>&3)
  if [[ -z "$DISK" ]]; then
    dialog --title "Error" --msgbox "Disk selection required." 6 40
    exit 1
  fi
}

# Partition disk using parted
function partition_disk() {
  dialog --title "Partitioning" --msgbox "You can choose to partition the disk automatically or manually. If you choose to partition automatically, it will erase all data on the disk." 10 80

  PARTITION_OPTION=$(dialog --title "Partitioning Option" --menu "Select an option:" 15 60 2 \
    1 "Automatically partition the entire disk" \
    2 "Manually partition the disk using parted" 3>&1 1>&2 2>&3)

  case "$PARTITION_OPTION" in
    1)
      log "Automatically partitioning $DISK..."
      # Create GPT partition table and partitions
      parted "$DISK" mklabel gpt || rollback
      parted "$DISK" mkpart primary fat32 1MiB 513MiB || rollback
      parted "$DISK" set 1 esp on || rollback
      parted "$DISK" mkpart primary 513MiB 100% || rollback
      
      # Create physical volume
      pvcreate "${DISK}2" || rollback
      # Create volume group
      vgcreate vg0 "${DISK}2" || rollback
      # Create logical volumes
      lvcreate -L 16G vg0 -n swap || rollback
      lvcreate -L 512M vg0 -n boot || rollback
      lvcreate -l 100%FREE vg0 -n root || rollback
      ;;
    2)
      dialog --title "Manual Partitioning" --msgbox "Please partition your disk manually using parted commands, then press OK to continue." 10 80
      parted "$DISK"
      ;;
    *)
      dialog --title "Error" --msgbox "Invalid option selected." 6 40
      exit 1
      ;;
  esac
}

# Format partitions with validation and rollback on failure
function format_partitions() {
  log "Formatting partitions..."
  mkfs.fat -F32 "${DISK}1" && log "EFI partition formatted successfully." || rollback
  mkfs.ext4 /dev/vg0/boot && log "BOOT partition formatted successfully." || rollback
  mkfs.ext4 /dev/vg0/root && log "ROOT partition formatted successfully." || rollback
  mkswap /dev/vg0/swap && log "Swap partition created successfully." || rollback
}

# Mount partitions with rollback tracking
function mount_partitions() {
  log "Mounting partitions..."
  mount /dev/vg0/root /mnt && ROLLBACK_STACK+=("umount /mnt") || rollback
  mkdir -p /mnt/boot
  mount /dev/vg0/boot /mnt/boot && ROLLBACK_STACK+=("umount /mnt/boot") || rollback
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
  HOSTNAME=$(dialog --title "Hostname" --inputbox "Enter the hostname for your MaiArch system:" 8 40 3>&1 1>&2 2>&3)
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
  GUI_CHOICE=$(dialog --title "Select GUI" --menu "Choose a Desktop Environment to install on MaiArch:" 15 40 3 \
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
log "Starting CLI-based MaiArch installation script..."
check_internet
select_disk

dialog --title "Warning" --msgbox "Automatic partitioning will erase ALL data on the selected disk!" 8 70

partition_disk
format_partitions
mount_partitions
install_base_system
generate_fstab
configure_system
set_root_password
install_gui
unmount_partitions

log "MaiArch installation complete. Please reboot."
dialog --title "Installation Complete" --msgbox "MaiArch installation complete! Please reboot your system." 8 40
