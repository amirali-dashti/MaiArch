#!/bin/bash

# Enforce Root Privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with root privileges (sudo)."
  exit 1
fi

# Check for dialog's existence (sonzai - existence)
if ! command -v dialog &> /dev/null; then
  echo "dialog is required for user interaction. Installing..."
  pacman -S --noconfirm dialog
fi

# Welcome Message
dialog --title "Welcome to MaiArch Installation" \
--msgbox "WARNING: THIS OS IS EARLY RELEASE AND UNSTABLE. USE WITH CAUTION!\nWelcome to the MaiArch Installer!" 15 50

# Confirmation Dialog
if ! dialog --title "MaiArch Installation Confirmation" --yesno "Are you ready to begin the installation process?" 7 50; then
  dialog --msgbox "Installation canceled. You can restart anytime." 5 40
  exit 1
fi

sudo pacman -Sy git
sudo pacman -Sy git

git clone https://github.com/archlinux/archinstall.git

mv Installer.py archinstall/archinstall/scripts/

python archinstall/archinstall/scripts/Installer.py

# Exit Message
dialog --msgbox "Installation completed.\nThanks for choosing MaiArch!\nIf you found any problem/bug, please report it at https://www.github.com/devtracer/MaiArch\nThe system will get rebooted." 5 40
