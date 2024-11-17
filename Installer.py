import os

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

configs_dict = {
    "bootloader": "systemd-bootctl",
    "debug": False,
    "harddrives": ["/dev/loop0"],  # Example of default value as a list
    "hostname": "development-box",
    "keyboard-layout": "us",
    "mirror-region": "Worldwide",
    "sys-encoding": "utf-8",
    "sys-language": "en_US",
    "timezone": "Europe/Stockholm",
    "packages": ["docker", "git", "wget", "zsh"]
}

clear_screen()

# Start of CLI interaction
print_colored("Welcome to the Configuration Setup", "cyan")
print("="*40)

# Prompt for GUI selection
VAL_GUI = OptionWindow("Choose between these GUIs (gnome is recommended)", ["gnome"])

# Bootloader selection
VAL_BOOTLOADER = SingleChoiceOptionWindow("Choose between these Bootloaders (grub is recommended)", ["grub", "systemd-bootctl"])

# Debug option
VAL_DEBUG = SingleChoiceOptionWindow("Enable or disable debug mode. (False is recommended)", ["False", "True"])

# Convert VAL_DEBUG to boolean
VAL_DEBUG = True if VAL_DEBUG == "True" else False

# Keyboard layout input
VAL_KEYBOARDLAYOUT = MultiSelectInputWindow("Type your keyboard layouts (Example: en_US, separate multiple choices with comma.) leave blank for en_US")
if not VAL_KEYBOARDLAYOUT:
    VAL_KEYBOARDLAYOUT = ["us"]

# Mirror region input
VAL_MIRROR = MultiSelectInputWindow("Choose your mirror (The country's name is capitalized, separate multiple choices with comma.) leave blank for Worldwide")
if not VAL_MIRROR:
    VAL_MIRROR = ["Worldwide"]

# Update configurations with user selections
configs_dict["bootloader"] = VAL_BOOTLOADER if VAL_BOOTLOADER else configs_dict["bootloader"]
configs_dict["debug"] = VAL_DEBUG
configs_dict["keyboard-layout"] = VAL_KEYBOARDLAYOUT
configs_dict["mirror-region"] = VAL_MIRROR

# Final output
clear_screen()
print_colored("Configuration Summary", "cyan")
print("="*40)
for key, value in configs_dict.items():
    print(f"{key.capitalize().replace('-', ' ')}: {value}")
