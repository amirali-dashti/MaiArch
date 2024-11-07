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
--msgbox "WARNING: THIS OS IS EARLY RELEASE AND UNSTABLE. USE WITH CAUTION!\nWelcome to the MaiArch Installer!" 15 50

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

# Install additional software
dialog --msgbox "Continuing with Installing 'Omnipkg', MaiArch's package manager." 5 40
git clone https://github.com/devtracer/Omnipkg.git
cd Omnipkg
chmod +x omnipkginstall.sh
sudo ./omnipkginstall.sh

dialog --msgbox "'Omnipkg' has been installed successfully. Continuing with installing Chromium, Wine, vim, and etc!" 5 40
omnipkg -a chromium
omnipkg -a wine
omnipkg -a vim

# Completion Message and Reboot Prompt
dialog --msgbox "Installation completed.\nThanks for choosing MaiArch!\nPlease report issues at https://www.github.com/devtracer/MaiArch." 8 50
if dialog --yesno "Would you like to reboot now?" 5 40; then
  reboot
else
  dialog --msgbox "You chose not to reboot. Remember to restart your system to apply changes." 5 40
fi
