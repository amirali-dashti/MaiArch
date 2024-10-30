#!/bin/bash

# Check if dialog is installed
if ! command -v dialog &> /dev/null
then
    echo "dialog is not installed. Installing..."
    sudo pacman -S dialog
    exit 1
fi

# Welcome Dialog
dialog --title "Welcome to MaiArch Installation" \
       --msgbox "\nWelcome to the MaiArch Installer!\n\nThis installation will guide you through setting up MaiArch, your custom Arch-based system.\n\nFirst, we will use the official Arch Installer to perform the base installation, ensuring reliability and precision.\n\nFollowing that, MaiArchInstaller will handle essential configurations and add files tailored to your system." 15 50

# Proceed Confirmation
dialog --title "MaiArch Installation Confirmation" \
       --yesno "Are you ready to start the installation process?" 7 50
if [ $? -ne 0 ]; then
    dialog --msgbox "Installation canceled. You can restart the installation anytime." 5 40
    clear
    exit 1
fi

# Begin Arch Installation using Archinstall
dialog --title "Starting Arch Install" \
       --infobox "Starting the Arch Installer...\n\nThe system will proceed with the Arch base installation." 7 50
sleep 2  # Delay for user readability (optional)

# Run the Arch Install process using archinstall's source code
git clone https://github.com/archlinux/archinstall.git

python archinstall/archinstall/__main__.py


if [ $? -ne 0 ]; then
    dialog --title "Installation Error" \
           --msgbox "The Arch installation encountered an error. Please review the logs and try again." 8 50
    clear
    exit 1
fi

# MaiArch Customization
dialog --title "MaiArch Customization" \
       --infobox "Proceeding with MaiArchInstaller for additional customization..." 5 50
sleep 2  # Delay for readability

# Run MaiArchInstaller (additional custom installation steps)
# Note: This is a placeholder. Replace with actual commands for MaiArch customization.
echo "Running MaiArchInstaller custom configurations..." # You can replace this with the actual command
# e.g., ./MaiArchInstaller.sh

dialog --title "Installation Complete" \
       --msgbox "Congratulations! MaiArch has been successfully installed and customized.\n\nPlease reboot your system to apply changes." 10 50

# End of script
clear
