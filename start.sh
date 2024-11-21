#!/bin/bash

# Script to install dependencies, set permissions, and run the Python installer

# Function to check if a command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install a package using pacman
install_package() {
    PACKAGE=$1
    if ! pacman -Q $PACKAGE &>/dev/null; then
        echo "Installing $PACKAGE..."
        if ! sudo pacman -S --noconfirm $PACKAGE; then
            echo "Error: Failed to install $PACKAGE. Please install it manually."
            exit 1
        fi
    else
        echo "$PACKAGE is already installed."
    fi
}

# Update system and check for sudo
echo "Updating system..."
if ! sudo pacman -Syu --noconfirm; then
    echo "Error: Failed to update system. Please check your internet connection or package manager."
    exit 1
fi

# Install required dependencies
echo "Checking and installing required dependencies..."
install_package python
install_package python-npyscreen
install_package python-archinstall

# Check if the Python script exists
PYTHON_FILE="MaiArchInstall.py"
if [ ! -f "$PYTHON_FILE" ]; then
    echo "Error: $PYTHON_FILE not found in the current directory."
    echo "Please ensure the file is in the same directory as this script."
    exit 1
fi

# Make the Python file executable
echo "Setting execute permissions on $PYTHON_FILE..."
chmod +x "$PYTHON_FILE"

# Run the Python script
echo "Running the Arch Installer Python script..."
if ! python "$PYTHON_FILE"; then
    echo "Error: Failed to execute $PYTHON_FILE."
    exit 1
fi

echo "Arch Installer completed successfully."
