import subprocess

def ButtonWindow(text):
    """Displays a message box with the given text."""
    subprocess.run(['dialog', '--msgbox', text, '10', '25'])

def OptionWindow(text, options):
    """
    Displays a menu dialog with the provided text and options.
    Returns the selected option or None if the dialog was canceled.
    """
    # Build options string for dialog command
    option_str = []
    for i, option in enumerate(options):
        option_str.extend([str(i), option])

    # Run the dialog command and capture the output
    result = subprocess.run(
        ['dialog', '--menu', text, '12', '45', '25'] + option_str,
        capture_output=True,
        text=True
    )

    # Check if the dialog was exited successfully
    if result.returncode == 0:
        # Return the selected option by index
        selected_index = int(result.stdout.strip())
        return options[selected_index]
    else:
        # Return None if the dialog was canceled
        return None

def InputWindow(prompt):
    """
    Displays an input dialog to receive a text entry from the user.
    Returns the entered text or None if the dialog was canceled.
    """
    # Run the dialog command to capture user input
    result = subprocess.run(
        ['dialog', '--inputbox', prompt, '10', '50'],
        capture_output=True,
        text=True
    )

    # Check if the dialog was exited successfully
    if result.returncode == 0:
        # Return the entered text
        return result.stdout.strip()
    else:
        # Return None if the dialog was canceled
        return None

def SingleChoiceOptionWindow(text, options):
    option_str = []
    for i, option in enumerate(options):
        option_str.extend([str(i), option, "off"])

    result = subprocess.run(
        ['dialog', '--radiolist', text, '12', '45', '25'] + option_str,
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        selected_index = int(result.stdout.strip())
        return options[selected_index]
    else:
        return None

def MultiSelectInputWindow(prompt):
    """
    Displays an input dialog to receive multiple comma-separated selections from the user.
    Returns a list of selections or None if the dialog was canceled.
    """
    result = subprocess.run(
        ['dialog', '--inputbox', prompt, '10', '50'],
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        # Split the input by commas, strip whitespace, and ignore empty results
        selections = [item.strip() for item in result.stdout.split(',') if item.strip()]
        return selections
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
VAL_BOOTLOADER = SingleChoiceOptionWindow("Choose between these Bootloader (grub is recommended)", ["grub", "systemd-bootctl"])
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

print(configs_dict)
