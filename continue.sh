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
--msgbox "Welcome again! we'll continue by installing needed additional packages." 15 50

dialog --title "OmniPkg" \
--msgbox "Installing wine, to have access to Windows apps via MaiArch." 15 50

#!/bin/bash

sudo pacman -Syu --noconfirm

if ! grep -q "\[multilib\]" /etc/pacman.conf; then
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Syu --noconfirm
fi

sudo pacman -S --noconfirm wine wine-mono wine-gecko winetricks

sudo pacman -S --noconfirm q4wine

if ! command -v yay &> /dev/null; then
    echo "Installing yay for AUR support..."
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
fi

yay -S --noconfirm wine-staging
echo "Wine, Wine GUI, and additional components have been installed successfully."


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
