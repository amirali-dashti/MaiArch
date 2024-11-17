def OptionWindow(text, options):
    """
    Displays a menu dialog with the provided text and options.
    Returns the selected option or None if the user opts out.
    """
    print(text)
    for i, option in enumerate(options, 1):
        print(f"{i}. {option}")
    
    try:
        choice = int(input("Select an option by number: "))
        if 1 <= choice <= len(options):
            return options[choice - 1]
        else:
            print("Invalid selection.")
            return None
    except ValueError:
        print("Invalid input.")
        return None

def SingleChoiceOptionWindow(text, options):
    """
    Displays a single-choice menu and returns the selected option.
    """
    print(text)
    for i, option in enumerate(options, 1):
        print(f"{i}. {option}")

    try:
        choice = int(input("Select an option by number: "))
        if 1 <= choice <= len(options):
            return options[choice - 1]
        else:
            print("Invalid selection.")
            return None
    except ValueError:
        print("Invalid input.")
        return None

def InputWindow(prompt):
    """
    Displays a prompt to receive a text entry from the user.
    Returns the entered text or None if the input was canceled.
    """
    return input(prompt + ": ")

def MultiSelectInputWindow(prompt):
    """
    Displays a prompt to receive multiple comma-separated selections from the user.
    Returns a list of selections or None if the input was canceled.
    """
    response = input(prompt + ": ")
    if response.strip():
        return [item.strip() for item in response.split(',') if item.strip()]
    else:
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

# Prompt for GUI selection
VAL_GUI = OptionWindow("Choose between these GUIs (gnome is recommended)", ["gnome"])
VAL_BOOTLOADER = SingleChoiceOptionWindow("Choose between these Bootloaders (grub is recommended)", ["grub", "systemd-bootctl"])
VAL_DEBUG = SingleChoiceOptionWindow("Enable or disable debug mode. (False is recommended)", ["False", "True"])

# Convert VAL_DEBUG to boolean
if VAL_DEBUG == "True":
    VAL_DEBUG = True
else:
    VAL_DEBUG = False

# Prompt for keyboard layout input, with fallback to 'us' if left empty
VAL_KEYBOARDLAYOUT = MultiSelectInputWindow("Type your keyboard layouts (Example: en_US, separate multiple choices with comma.) leave blank for en_US")
if not VAL_KEYBOARDLAYOUT:
    VAL_KEYBOARDLAYOUT = ["us"]

# Prompt for mirror region input, with fallback to 'Worldwide' if left empty
VAL_MIRROR = MultiSelectInputWindow("Choose your mirror: (The country's name is capitalized. separate multiple choices with comma.) leave blank for Worldwide")
if not VAL_MIRROR:
    VAL_MIRROR = ["Worldwide"]

# Update configurations with user selections
configs_dict["bootloader"] = VAL_BOOTLOADER if VAL_BOOTLOADER else configs_dict["bootloader"]
configs_dict["debug"] = VAL_DEBUG
configs_dict["keyboard-layout"] = VAL_KEYBOARDLAYOUT
configs_dict["mirror-region"] = VAL_MIRROR

print("\nFinal Configuration:")
print(configs_dict)
