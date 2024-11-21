from pathlib import Path
from archinstall import *
import os


def display_window(title, content):
    """Displays a simple ASCII window with a title and content."""
    width = 60
    print("\n" + "-" * width)
    print(f"| {title.center(width - 2)} |")
    print("-" * width)
    for line in content:
        print(f"| {line.ljust(width - 2)} |")
    print("-" * width)


def prompt_user(prompt):
    """Prompts the user for input."""
    return input(f"\n{prompt}: ").strip()


def confirm(prompt):
    """Prompts the user for a yes/no confirmation."""
    choice = input(f"\n{prompt} (y/n): ").strip().lower()
    return choice in ['y', 'yes']


def clear_screen():
    """Clears the terminal screen."""
    os.system("clear" if os.name == "posix" else "cls")


def main():
    clear_screen()
    display_window("Arch Linux Installer", ["Welcome to the Arch Linux Installer", "Follow the steps to configure your system."])
    
    # Step 1: Select a device
    clear_screen()
    display_window("Disk Selection", ["Select a disk for installation"])
    try:
        disk_config = select_disk_config()
        display_window("Disk Selected", [f"Disk: {disk_config.device}", "Press Enter to continue..."])
        input()
    except Exception as e:
        display_window("Error", [f"Failed to select disk: {e}"])
        return

    # Step 2: Configure encryption
    clear_screen()
    display_window("Encryption Configuration", ["Would you like to enable disk encryption?"])
    disk_encryption = None
    if confirm("Enable disk encryption"):
        try:
            data_store = {}
            disk_encryption = DiskEncryptionMenu(disk_config.device_modifications, data_store).run()
            display_window("Encryption Configured", ["Disk encryption has been configured."])
        except Exception as e:
            display_window("Error", [f"Failed to configure encryption: {e}"])
            return

    # Step 3: Perform filesystem operations
    clear_screen()
    display_window("Filesystem Operations", ["Warning: This will format the selected disk.", "All data will be deleted!"])
    if confirm("Proceed with formatting the disk"):
        try:
            fs_handler = FilesystemHandler(disk_config, disk_encryption)
            fs_handler.perform_filesystem_operations()
            display_window("Success", ["Filesystem operations completed successfully."])
        except Exception as e:
            display_window("Error", [f"Failed to perform filesystem operations: {e}"])
            return
    else:
        display_window("Aborted", ["Disk formatting was aborted."])
        return

    # Step 4: Configure installation
    clear_screen()
    hostname = prompt_user("Enter a hostname for the system (default: minimal-arch)") or "minimal-arch"
    additional_packages = prompt_user("Enter additional packages (comma-separated, default: nano, wget, git)") or "nano,wget,git"
    additional_packages = [pkg.strip() for pkg in additional_packages.split(",")]

    # Step 5: Install the system
    clear_screen()
    display_window("Installing System", ["Starting installation process..."])
    try:
        mountpoint = Path("/tmp")
        with Installer(
            mountpoint,
            disk_config,
            disk_encryption=disk_encryption,
            kernels=["linux"]
        ) as installation:
            installation.mount_ordered_layout()
            installation.minimal_installation(hostname=hostname)
            installation.add_additional_packages(additional_packages)
            profile_config = ProfileConfiguration(MinimalProfile())
            profile_handler.install_profile_config(installation, profile_config)
            user = User("archinstall", "password", True)
            installation.create_users(user)
        display_window("Success", ["Installation completed successfully!", "Press Enter to finish."])
        input()
    except Exception as e:
        display_window("Error", [f"Installation failed: {e}"])
        return


if __name__ == "__main__":
    main()
