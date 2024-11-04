#!/bin/bash

# Update package lists and install dialog
sudo pacman -Sy dialog

# Create a user account
read -p "Enter username: " username
read -s -p "Enter password: " password

sudo useradd -m "$username"
sudo passwd "$username" <<< "$password"

# Install Xorg and a desktop environment (e.g., GNOME)
sudo pacman -S xorg-server gnome

# Configure network settings (example)
sudo nano /etc/network/interfaces

# Start the display server and desktop environment
sudo systemctl start display-manager
