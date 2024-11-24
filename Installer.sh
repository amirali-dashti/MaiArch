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

# Install required packages
pacman -Sy --noconfirm git || { echo "Failed to update/install 'git'. Exiting."; exit 1; }

# Clone the archinstall repository
git clone "$REPO_URL" || { echo "Failed to clone repository. Exiting."; exit 1; }

# Move custom installer script
mv Installer.py "$INSTALL_SCRIPT" || { echo "Failed to move Installer.py. Exiting."; exit 1; }

# Run the custom installer
python "$INSTALL_SCRIPT" || { echo "Custom installer script failed. Exiting."; exit 1; }

# Message and additional package installations
dialog --msgbox "The base has been installed." 5 40

dialog --msgbox "Continuing with installing your side apps." 5 40

dialog --msgbox "Starting with TuxTalk, MaiArch's AI assistant..." 5 40

cd ¬/Downloads || { dialog --msgbox "TuxTalk's installation has failed. continuing." 5 40}
git clone https://github.com/devtracer/TuxTalk.git || { dialog --msgbox "TuxTalk's installation has failed. continuing." 5 40}
cd TuxTalk || { dialog --msgbox "TuxTalk's installation has failed. continuing." 5 40}
chmod +x ./Installer.sh || { dialog --msgbox "TuxTalk's installation has failed. continuing." 5 40}
./Installer.sh || { dialog --msgbox "TuxTalk's installation has failed. continuing." 5 40}

dialog --msgbox "Continuing with installing OmniPkg, MaiArch's default package manager..." 5 40
cd ¬/Downloads || { dialog --msgbox "Omnipkg's installation has failed. continuing." 5 40}
git clone https://github.com/devtracer/OmniPkg.git || { dialog --msgbox "Omnipkg's installation has failed. continuing." 5 40}
cd OmniPkg || { dialog --msgbox "Omnipkg's installation has failed. continuing." 5 40}
chmod +x omnipkginstall.sh || { dialog --msgbox "Omnipkg's installation has failed. continuing." 5 40}
./omnipkginstall.sh || { dialog --msgbox "Omnipkg's installation has failed. continuing." 5 40}

dialog --msgbox "The installations's completed. Now we'll restart your device..." 5 40
reboot