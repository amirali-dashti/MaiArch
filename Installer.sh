#!/bin/bash

# Enforce Root Privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with root privileges (sudo)."
  exit 1
fi

# Check for dialog's existence (sonzai - existence)
if ! command -v dialog &> /dev/null; then
  echo "dialog is required for user interaction. Installing..."
  pacman -S --noconfirm dialog || { echo "Failed to install 'dialog'. Exiting."; exit 1; }
fi

# Variables
REPO_URL="https://github.com/archlinux/archinstall.git"
INSTALL_SCRIPT="archinstall/archinstall/scripts/Installer.py"

# Welcome Message
dialog --title "Welcome to MaiArch Installation" \
--msgbox "WARNING: THIS OS IS EARLY RELEASE AND UNSTABLE. USE WITH CAUTION!\nWelcome to the MaiArch Installer!" 5 40

# Confirmation Dialog
if ! dialog --title "MaiArch Installation Confirmation" \
   --yesno "By pressing 'yes', MaiArch will be installed. This includes:\n- Base OS installation\n- Additional packages: 'Cortex Penguin' and 'OmniPkg' (see https://github.com/devtracer)." 15 50; then
  dialog --msgbox "Installation canceled. You can restart anytime." 5 40
  exit 1
fi

dialog --msgbox "Getting into the base installation process. Check https://github.com/devtracer/MaiArch.git for a guided tutorial." 5 40

# Install required packages
pacman -Sy --noconfirm git || { echo "Failed to update/install 'git'. Exiting."; exit 1; }

# Giving permission to all files, perchance the user didnt

chmod +x * || { echo "Failed to give permission. Exiting."; exit 1; }

# Clone the archinstall repository
#git clone "$REPO_URL" || { echo "Failed to clone repository. Exiting."; exit 1; }

# Unpacking archinstall file

pacman -Sy unzip || { echo "Failed to Unzip. Exiting."; exit 1; }

unzip archinstall.zip || { echo "Failed to Unzip. Exiting."; exit 1; }

# Move custom installer script
mv Installer.py "$INSTALL_SCRIPT" || { echo "Failed to move Installer.py. Exiting."; exit 1; }

# Run the custom installer
python3 "$INSTALL_SCRIPT" || { echo "MaiArch installer script failed. Exiting."; exit 1; }

# Message and additional package installations
dialog --msgbox "The base has been installed." 5 40

dialog --msgbox "Continuing with installing your side apps." 5 40

dialog --msgbox "Starting with TuxTalk, MaiArch's AI assistant..." 5 40

# Function to handle dialog error messages
show_error() {
    dialog --msgbox "$1" 7 50
}

#!/bin/bash

# Function to handle dialog error messages
show_error() {
    dialog --msgbox "$1\n\nError details:\n$(<error.log)" 15 70
}

# Redirect all errors to a log file for debugging
exec 2>error.log

# Install TuxTalk
if git clone https://github.com/devtracer/TuxTalk.git && cd TuxTalk && chmod +x ./TuxTalkInstall.sh && ./TuxTalkInstall.sh; then
    dialog --msgbox "TuxTalk has been installed successfully. Proceeding to install OmniPkg, MaiArch's default package manager..." 7 50
    cd ..  # Return to the previous directory
else
    show_error "TuxTalk installation failed. Please check the errors and try again. For assistance, visit: https://www.github.com/devtracer/TuxTalk.git."
    exit 1
fi

# Install OmniPkg
if git clone https://github.com/devtracer/OmniPkg.git && cd OmniPkg && chmod +x Installation.sh && ./Installation.sh; then
    dialog --msgbox "Continuing with installing some applications." 7 50

    # Install desired applications using OmniPkg
    if omnipkg install nautilus konsole google-chrome evince vlc; then
        dialog --msgbox "The installation is complete. The system will now restart..." 7 50
    else
        show_error "Failed to install one or more applications using OmniPkg. Please check the errors and try again."
        exit 1
    fi

    # Ask for confirmation before rebooting
    dialog --yesno "The system will now restart. Do you want to proceed?" 7 50
    if [ $? -eq 0 ]; then
        reboot
    else
        dialog --msgbox "Reboot canceled. Please reboot manually to apply changes." 7 50
    fi
    cd ..  # Return to the previous directory
else
    show_error "OmniPkg installation failed. Please check the errors and try again. For assistance, visit: https://www.github.com/devtracer/OmniPkg.git."
    exit 1
fi
