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
if ! dialog --title "MaiArch Installation Confirmation" --yesno "By pressing the 'yes' button, MaiArch will get installed. The process contains the base installation of the Operating System via the 'archinstall' package. Then, the process will get continued with installing more packages. Including but not limited to 'Cortex Penguin' and 'OmniPkg'. (The source code of both are available on https://github.com/devtracer)" 7 50; then
  dialog --msgbox "Installation canceled. You can restart anytime." 5 40
  exit 1
fi

sudo pacman -Sy git
sudo pacman -Sy git

git clone https://github.com/archlinux/archinstall.git

mv Installer.py archinstall/archinstall/scripts/

python archinstall/archinstall/scripts/Installer.py

dialog --msgbox "The base has been installed." 5 40


dialog --msgbox "Installation completed.\nThanks for choosing MaiArch!\nIf you found any problem/bug, please report it at https://www.github.com/devtracer/MaiArch\nThe system will get rebooted." 5 40
