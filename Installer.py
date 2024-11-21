from pathlib import Path
import archinstall
from archinstall import info, debug
from archinstall import SysInfo
from archinstall.lib import locale, disk
from archinstall.lib.global_menu import GlobalMenu
from archinstall.lib.configuration import ConfigurationOutput
from archinstall.lib.installer import Installer
from archinstall.lib.models import AudioConfiguration, Bootloader
from archinstall.lib.models.network_configuration import NetworkConfiguration
from archinstall.lib.profile.profiles_handler import profile_handler
import logging
import os
import time


# Configure logging
logging.basicConfig(level=logging.INFO)


def clear_screen():
    """Clears the terminal screen."""
    os.system("clear" if os.name == "posix" else "cls")


def display_window(title, content):
    """Displays a simple ASCII window with a title and content."""
    width = 60
    print("\n" + "-" * width)
    print(f"| {title.center(width - 2)} |")
    print("-" * width)
    for line in content:
        print(f"| {line.ljust(width - 2)} |")
    print("-" * width)


def prompt_user(prompt, default=None):
    """Prompts the user for input with an optional default value."""
    user_input = input(f"{prompt} [{default}]: ").strip()
    return user_input if user_input else default


def confirm_action(prompt):
    """Prompts the user for a yes/no confirmation."""
    choice = input(f"{prompt} (y/n): ").strip().lower()
    return choice in ["y", "yes"]


def progress_bar(title, steps, action):
    """Shows a simple progress bar during long-running operations."""
    width = 50
    print(f"\n{title}")
    for step in range(1, steps + 1):
        time.sleep(0.3)  # Simulate progress
        action(step) if callable(action) else None
        completed = int((step / steps) * width)
        print(f"[{'#' * completed}{'.' * (width - completed)}] {int((step / steps) * 100)}%", end="\r")
    print("\n")


def ask_disk_config():
    """Handles disk selection and encryption."""
    clear_screen()
    display_window("Disk Configuration", ["Select a disk for installation"])
    try:
        disk_config = select_disk_config()
        display_window("Disk Selected", [f"Disk: {disk_config.device}"])
        if confirm_action("Enable disk encryption?"):
            data_store = {}
            disk_encryption = DiskEncryptionMenu(disk_config.device_modifications, data_store).run()
        else:
            disk_encryption = None
        return disk_config, disk_encryption
    except Exception as e:
        display_window("Error", [f"Failed to select disk: {e}"])
        exit(1)


def ask_installation_details():
    """Prompts the user for basic installation details."""
    hostname = prompt_user("Enter hostname", "archlinux")
    kernels = prompt_user("Enter kernel(s) to install (comma-separated)", "linux").split(",")
    packages = prompt_user("Enter additional packages (comma-separated)", "nano,wget,git").split(",")
    return hostname, kernels, packages


def ask_audio_config():
    """Configures audio setup."""
    clear_screen()
    display_window("Audio Configuration", ["Choose an audio setup"])
    print("1. PulseAudio\n2. PipeWire\n3. No Audio")
    choice = input("\nSelect an option (1/2/3): ").strip()
    if choice == "1":
        return AudioConfiguration.pulseaudio()
    elif choice == "2":
        return AudioConfiguration.pipewire()
    else:
        return None


def ask_network_config():
    """Configures network setup."""
    clear_screen()
    display_window("Network Configuration", ["Choose a network setup"])
    print("1. Use DHCP\n2. Manual Configuration\n3. Skip Network Configuration")
    choice = input("\nSelect an option (1/2/3): ").strip()
    if choice == "1":
        return NetworkConfiguration.dhcp()
    elif choice == "2":
        interface = prompt_user("Enter network interface", "eth0")
        ip = prompt_user("Enter IP address", "192.168.1.100")
        gateway = prompt_user("Enter Gateway", "192.168.1.1")
        dns = prompt_user("Enter DNS server", "8.8.8.8")
        return NetworkConfiguration.static(interface, ip, gateway, dns)
    else:
        return None


def run_installation(disk_config, disk_encryption, hostname, kernels, packages, audio_config, network_config):
    """Runs the installation process."""
    mountpoint = Path("/mnt")
    try:
        with Installer(mountpoint, disk_config, disk_encryption=disk_encryption, kernels=kernels) as installation:
            progress_bar("Mounting layout...", 10, lambda _: installation.mount_ordered_layout())

            progress_bar("Performing base installation...", 20, lambda _: installation.minimal_installation(hostname=hostname))

            progress_bar("Adding additional packages...", 15, lambda _: installation.add_additional_packages(packages))

            profile_config = ProfileConfiguration(profile_handler.empty_profile())
            progress_bar("Configuring profiles...", 10, lambda _: profile_handler.install_profile_config(installation, profile_config))

            root_pw = prompt_user("Enter root password", "root")
            installation.user_set_pw("root", root_pw)
            user_name = prompt_user("Enter user name", "archuser")
            user_pw = prompt_user("Enter password for user", "password")
            progress_bar("Setting up users...", 5, lambda _: installation.create_users([User(user_name, user_pw, True)]))

            if audio_config:
                progress_bar("Installing audio configuration...", 5, lambda _: audio_config.install_audio_config(installation))

            if network_config:
                progress_bar("Installing network configuration...", 5, lambda _: network_config.install_network_config(installation, profile_config))

            progress_bar("Generating fstab...", 5, lambda _: installation.genfstab())
            display_window("Success", ["Installation completed successfully!"])
    except Exception as e:
        display_window("Error", [f"Installation failed: {e}"])
        exit(1)


def main():
    """Main function to run the installer."""
    clear_screen()
    display_window("Welcome to Arch Installer", ["Follow the steps to configure your system."])

    # Disk and encryption configuration
    disk_config, disk_encryption = ask_disk_config()

    # Perform filesystem operations
    display_window("Filesystem Operations", ["Warning: This will format the selected disk."])
    if confirm_action("Proceed with formatting the disk?"):
        fs_handler = FilesystemHandler(disk_config, disk_encryption)
        progress_bar("Formatting disk...", 15, lambda _: fs_handler.perform_filesystem_operations())
    else:
        display_window("Aborted", ["Disk formatting was canceled."])
        exit(1)

    # Installation details
    hostname, kernels, packages = ask_installation_details()

    # Audio configuration
    audio_config = ask_audio_config()

    # Network configuration
    network_config = ask_network_config()

    # Run installation
    run_installation(disk_config, disk_encryption, hostname, kernels, packages, audio_config, network_config)


if __name__ == "__main__":
    main()
