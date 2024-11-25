#!/bin/bash

# Enforce Root Privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with root privileges (sudo)."
  exit 1
fi

# Welcome Message
dialog --title "Welcome to MaiArch Installation" \
--msgbox "WARNING: THIS CODE IS EARLY RELEASE AND UNSTABLE. USE WITH CAUTION!\nWelcome to the MaiArch Installer!" 5 40

# Check for dialog's existence (sonzai - existence)
if ! command -v dialog &> /dev/null; then
  echo "dialog is required for user interaction. Installing..."
  pacman -S --noconfirm dialog || { echo "Failed to install 'dialog'. Exiting."; exit 1; }
fi

# Confirmation Dialog
if ! dialog --title "MaiArch Installation Confirmation" \
   --yesno "By pressing 'yes', MaiArch will be installed and the changes will get stablished. This includes:\n-Additional packages: 'Cortex Penguin' and 'OmniPkg' (see https://github.com/devtracer)." 15 50; then
  dialog --msgbox "Installation canceled. You can restart anytime." 5 40
  exit 1
fi


dialog --msgbox "Starting with TuxTalk, MaiArch's AI assistant..." 5 40

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
