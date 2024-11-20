import os
from pathlib import Path
from JsonAccess import updateConfig
from DiskPreview import showDiskStatus
from archinstall import Installer, ProfileConfiguration, profile_handler, User
from archinstall.default_profiles.minimal import MinimalProfile
from archinstall.lib.disk.device_model import FilesystemType
from archinstall.lib.disk.encryption_menu import DiskEncryptionMenu
from archinstall.lib.disk.filesystem import FilesystemHandler
from archinstall.lib.interactions.disk_conf import select_disk_config

# Function to clear the screen for better readability
def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

# Function to print a colored message
def print_colored(text, color="white"):
    colors = {
        "red": "\033[91m", 
        "green": "\033[92m", 
        "yellow": "\033[93m", 
        "blue": "\033[94m", 
        "purple": "\033[95m", 
        "cyan": "\033[96m", 
        "white": "\033[97m", 
        "reset": "\033[0m"
    }
    print(f"{colors.get(color, colors['white'])}{text}{colors['reset']}")

def OptionWindow(text, options):
    """
    Displays a menu dialog with the provided text and options.
    Returns the selected option or None if the dialog was canceled.
    """
    print_colored(text, "blue")
    for i, option in enumerate(options, 1):
        print(f"{i}. {option}")
    
    while True:
        try:
            choice = int(input(f"\nSelect an option (1-{len(options)}): "))
            if 1 <= choice <= len(options):
                return options[choice - 1]
            else:
                print_colored("Invalid selection. Please try again.", "red")
        except ValueError:
            print_colored("Invalid input. Please enter a number.", "red")

def SingleChoiceOptionWindow(text, options):
    """
    Displays a single-choice menu and returns the selected option.
    """
    print_colored(text, "green")
    for i, option in enumerate(options, 1):
        print(f"{i}. {option}")

    while True:
        try:
            choice = int(input(f"\nSelect an option (1-{len(options)}): "))
            if 1 <= choice <= len(options):
                return options[choice - 1]
            else:
                print_colored("Invalid selection. Please try again.", "red")
        except ValueError:
            print_colored("Invalid input. Please enter a number.", "red")

def InputWindow(prompt):
    """
    Displays a prompt to receive a text entry from the user.
    Returns the entered text or None if the dialog was canceled.
    """
    response = input(f"{prompt}: ")
    return response.strip() if response.strip() else None

def MultiSelectInputWindow(prompt):
    """
    Displays a prompt to receive multiple comma-separated selections from the user.
    Returns a list of selections or None if the dialog was canceled.
    """
    response = input(f"{prompt}: ")
    if response.strip():
        return [item.strip() for item in response.split(',') if item.strip()]
    return None

# Main Installation Script
fs_type = FilesystemType('ext4')

# Initialize the disk configuration process using your OptionWindow
clear_screen()
print_colored("Welcome to the Arch Linux Installation", "blue")

# Select a disk
selected_disk = OptionWindow("Select a disk for installation:", ["Disk 1", "Disk 2", "Disk 3"])  # replace with dynamic disk list
print_colored(f"Selected disk: {selected_disk}", "green")

# Show disk status before proceeding
showDiskStatus(selected_disk)

# Ask for disk encryption configuration
disk_encryption_choice = SingleChoiceOptionWindow("Would you like to enable disk encryption?", ["Yes", "No"])
disk_encryption = None
if disk_encryption_choice == "Yes":
    disk_encryption = OptionWindow("Select encryption type:", ["LUKS", "None"])  # Simulating encryption types
    print_colored(f"Selected encryption: {disk_encryption}", "green")

# Select disk configuration
disk_config = select_disk_config()  # Use your actual disk selection logic here

# Initiate Filesystem handler
fs_handler = FilesystemHandler(disk_config, disk_encryption)

# Perform filesystem operations with a message
clear_screen()
print_colored("Performing filesystem operations. This may take some time...", "blue")
fs_handler.perform_filesystem_operations()

# Proceed with installation
mountpoint = Path('/mnt')

with Installer(
        mountpoint,
        disk_config,
        disk_encryption=disk_encryption,
        kernels=['linux']
) as installation:
    installation.mount_ordered_layout()
    installation.minimal_installation(hostname='minimal-arch')
    installation.add_additional_packages(['nano', 'wget', 'git'])

    # Optionally install a profile (here we use a minimal profile)
    profile_config = ProfileConfiguration(MinimalProfile())
    profile_handler.install_profile_config(installation, profile_config)

    # User creation - TUI style
    clear_screen()
    create_user_choice = SingleChoiceOptionWindow("Would you like to create a user?", ["Yes", "No"])

    if create_user_choice == "Yes":
        username = InputWindow("Enter a username")
        password = InputWindow("Enter a password")
        user = User(username, password, True)
        installation.create_users(user)
        print_colored(f"User {username} created successfully.", "green")
    else:
        print_colored("Skipping user creation.", "yellow")

clear_screen()
print_colored("Installation complete! Please reboot your system.", "green")
