#!/bin/bash

LOG_FILE="/var/log/arch_install.log"

# Log function for consistent output
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Install dialog if not already installed
sudo pacman -S --noconfirm dialog &>> "$LOG_FILE"
if [ $? -ne 0 ]; then
    log "Failed to install dialog. Check your package manager or network connection."
    exit 1
fi

# Function to check internet connection
speed_internet_connection() {
    if ping -c 1 archlinux.org &> /dev/null; then
        dialog --msgbox "You have an Internet connection. You can continue." 10 40
    else
        dialog --msgbox "No Internet connection detected. Please provide network details." 10 40
        dialog --form "Network Information" 15 50 0 \
            "Network Interface:" 1 1 "" 1 20 20 0 \
            "SSID:" 2 1 "" 2 20 20 0 \
            "Password:" 3 1 "" 3 20 20 0 2> /tmp/network_info

        network_interface=$(sed -n '1p' /tmp/network_info)
        ssid=$(sed -n '2p' /tmp/network_info)
        password=$(sed -n '3p' /tmp/network_info)

        iwctl station "$network_interface" connect "$ssid" --passphrase "$password" &>> "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "Failed to connect to network $ssid."
            speed_internet_connection
        else
            log "Connected to network $ssid successfully."
        fi
    fi
}

# Function to synchronize time
time_sync() {
    timedatectl set-ntp true &>> "$LOG_FILE"
    if timedatectl status | grep -q "System clock synchronized: yes"; then
        dialog --msgbox "Time has been synced." 10 40
        log "Time synchronization successful."
    else
        dialog --msgbox "Time synchronization failed. Check your internet connection or try manually." 10 40
        log "Time synchronization failed."
        time_sync
    fi
}

# Function for partitioning and formatting the disk with wipe option
partition_formatting_process() {
    dialog --inputbox "Enter the disk to partition (e.g., /dev/sda):" 10 40 2> /tmp/disk_choice
    disk_choice=$(< /tmp/disk_choice)

    # Ask if the user wants to wipe the entire disk
    dialog --yesno "WARNING: This will erase ALL data on $disk_choice. Do you want to continue?" 10 40
    if [ $? -eq 0 ]; then
        # Confirm again for safety
        dialog --yesno "Are you absolutely sure you want to wipe $disk_choice and use it for installation?" 10 40
        if [ $? -eq 0 ]; then
            # Wipe the disk
            log "Wiping $disk_choice..."
            wipefs -a "$disk_choice" &>> "$LOG_FILE"
            sgdisk --zap-all "$disk_choice" &>> "$LOG_FILE"
            if [ $? -ne 0 ]; then
                log "Failed to wipe disk $disk_choice."
                exit 1
            fi
            log "Disk $disk_choice wiped successfully."

            # Create new partition table with sfdisk
            echo -e ",512M,S\n,,L" | sfdisk "$disk_choice" &>> "$LOG_FILE"
            if [ $? -ne 0 ]; then
                log "Disk partitioning failed for $disk_choice."
                exit 1
            fi

            # Format the partitions
            mkfs.ext4 "${disk_choice}1" &>> "$LOG_FILE"
            mkswap "${disk_choice}2" &>> "$LOG_FILE"
            swapon "${disk_choice}2" &>> "$LOG_FILE"
            mount "${disk_choice}1" /mnt &>> "$LOG_FILE"
            if [ $? -ne 0 ]; then
                log "Failed to mount ${disk_choice}1."
                exit 1
            fi
            log "Partitioning, formatting, and mounting completed for $disk_choice."
        else
            log "Disk wipe cancelled by user."
            exit 1
        fi
    else
        log "Disk wipe option declined. Proceeding without wiping."
        
        # Optional: Proceed with manual partitioning if desired
        dialog --msgbox "Proceeding with manual partitioning on $disk_choice." 10 40
    fi
}

# Function to install the base Arch system
main_installation() {
    pacstrap /mnt base linux linux-firmware &>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        log "Base installation failed."
        exit 1
    fi

    genfstab -U /mnt >> /mnt/etc/fstab
    if [ $? -ne 0 ]; then
        log "Failed to generate fstab."
        exit 1
    fi

    log "Base installation completed successfully."
}

# Function to set username and password
username_password() {
    dialog --inputbox "Enter a username:" 10 40 2> /tmp/username
    username=$(< /tmp/username)

    dialog --passwordbox "Enter a password for $username:" 10 40 2> /tmp/user_password
    user_password=$(< /tmp/user_password)

    arch-chroot /mnt useradd -m "$username" &>> "$LOG_FILE"
    echo "$username:$user_password" | arch-chroot /mnt chpasswd &>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        log "Failed to set username or password."
        exit 1
    fi
    log "User $username added successfully."
}

# Function to configure timezone
timezone_configuration() {
    dialog --inputbox "Enter your timezone (e.g., Region/City like 'Asia/Tehran'):" 10 40 2> /tmp/timezone
    timezone=$(< /tmp/timezone)

    arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime &>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        log "Failed to set timezone to $timezone."
        exit 1
    fi

    arch-chroot /mnt hwclock --systohc &>> "$LOG_FILE"
    log "Timezone set to $timezone and hardware clock synchronized."
}

# Function to configure locale
locale_configuration() {
    dialog --inputbox "Enter your locale (e.g., en_US.UTF-8):" 10 40 2> /tmp/locale
    locale=$(< /tmp/locale)

    echo "$locale UTF-8" >> /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen &>> "$LOG_FILE"

    echo "LANG=$locale" > /mnt/etc/locale.conf
    if [ $? -ne 0 ]; then
        log "Failed to set locale to $locale."
        exit 1
    fi
    log "Locale set to $locale."
}

# Function to install GNOME desktop environment
install_gnome() {
    dialog --msgbox "Installing GNOME. This may take some time." 10 40
    arch-chroot /mnt pacman -S --noconfirm gnome gnome-extra networkmanager &>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        log "GNOME installation failed."
        exit 1
    fi

    arch-chroot /mnt systemctl enable gdm &>> "$LOG_FILE"
    arch-chroot /mnt systemctl enable NetworkManager &>> "$LOG_FILE"
    log "GNOME and NetworkManager installed and enabled successfully."
}

# Main flow
log "Starting installation process."
speed_internet_connection
time_sync
partition_formatting_process
main_installation
username_password
timezone_configuration
locale_configuration
install_gnome

dialog --msgbox "Installation complete! You can now reboot." 10 40
log "Installation process completed successfully."
