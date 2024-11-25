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
   --yesno "By pressing 'yes', MaiArch will be installed and the changes will get stablished. This includes:\n- Base OS installation\n- Additional packages: 'Cortex Penguin' and 'OmniPkg' (see https://github.com/devtracer)." 15 50; then
  dialog --msgbox "Installation canceled. You can restart anytime." 5 40
  exit 1
fi

dialog --msgbox "Getting into the base installation process. Check https://github.com/devtracer/MaiArch.git for a guided tutorial." 40 40

# Install required packages
# pacman -Sy --noconfirm git || { echo "Failed to update/install 'git'. Exiting."; exit 1; }

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

sudo ./Convertor.sh