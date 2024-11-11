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

dialog --title "Welcome to MaiArch Installation" \
--msgbox "WARNING: THIS CUSTOMIZER IS EARLY RELEASE AND UNSTABLE. USE WITH CAUTION!\nWelcome to the MaiArch Convertor!" 15 50

dialog --title "OmniPkg" \
--msgbox "Installing OmniPkg, MaiArch's default package manager." 15 50

git clone https://github.com/devtracer/OmniPkg.git
cd OmniPkg
chmod +x omnipkginstall.sh
./omnipkginstall.sh

dialog --msgbox "Continuing with installing TuxTalk, MaiArch's AI assistant." 5 40

cd ..

git clone https://github.com/devtracer/TuxTalk.git
cd TuxTalk
chmod +x ./Installer.sh
./Installer.sh

dialog --msgbox "Convertion has happened successfully." 5 40
