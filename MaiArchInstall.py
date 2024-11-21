# File: MaiArchInstall.py

from pathlib import Path
import os
import subprocess
import sys
from archinstall import Installer, ProfileConfiguration, profile_handler, User
from archinstall.default_profiles.minimal import MinimalProfile
from archinstall.lib.disk.device_model import FilesystemType
from archinstall.lib.disk.encryption_menu import DiskEncryptionMenu
from archinstall.lib.disk.filesystem import FilesystemHandler
from archinstall.lib.interactions.disk_conf import select_disk_config

# Dependency Checker
def check_and_install_dependencies():
    """Check and install required dependencies for the script."""
    dependencies = {
        "python": "Python 3",
        "python-archinstall": "ArchInstall library",
    }
    missing = []

    for package, desc in dependencies.items():
        try:
            subprocess.run(["pacman", "-Q", package], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            missing.append(package)

    if missing:
        print(f"The following dependencies are missing: {', '.join(missing)}")
        print("Attempting to install them now using pacman...")
        try:
            subprocess.run(["sudo", "pacman", "-S", "--noconfirm", *missing], check=True)
            print("All dependencies installed successfully.")
        except subprocess.CalledProcessError:
            print(f"Failed to install: {', '.join(missing)}")
            sys.exit(1)
    else:
        print("All required dependencies are already installed.")

# TUI Class
class ArchInstallerTUI:
    def __init__(self):
        self.fs_type = "ext4"
        self.disk_config = None
        self.disk_encryption = None
        self.hostname = "minimal-arch"
        self.additional_packages = ["nano", "wget", "git"]
        self.custom_commands = [
            "pacman -Syu --noconfirm",
            "pacman -S htop neofetch --noconfirm"
        ]

    def display_tui(self):
        """Displays the Text User Interface."""
        while True:
            self.clear_screen()
            print(self.build_window("Arch Installer TUI", [
                "1. Select Disk Configuration",
                "2. Set Filesystem Type",
                "3. Configure Encryption",
                "4. Set Hostname",
                "5. Add Additional Packages",
                "6. Run Installation",
                "7. Exit"
            ]))
            choice = input("\nEnter your choice: ").strip()
            if choice == "1":
                self.select_disk_config()
            elif choice == "2":
                self.set_filesystem_type()
            elif choice == "3":
                self.configure_encryption()
            elif choice == "4":
                self.set_hostname()
            elif choice == "5":
                self.add_packages()
            elif choice == "6":
                self.run_installation()
            elif choice == "7":
                print("Exiting... Goodbye!")
                break
            else:
                print("\nInvalid option. Please try again.")

    def build_window(self, title, options):
        """Builds a simple ASCII window."""
        width = 50
        lines = [f"{'-' * width}", f"| {title.center(width - 4)} |", f"{'-' * width}"]
        for option in options:
            lines.append(f"| {option.ljust(width - 4)} |")
        lines.append(f"{'-' * width}")
        return "\n".join(lines)

    def clear_screen(self):
        """Clears the terminal screen."""
        os.system("clear" if os.name == "posix" else "cls")

    def select_disk_config(self):
        """Handles disk configuration."""
        try:
            self.disk_config = select_disk_config()
            print(f"\nDisk selected: {self.disk_config.device}")
        except Exception as e:
            print(f"\nError selecting disk: {e}")

    def set_filesystem_type(self):
        """Sets the filesystem type."""
        print(self.build_window("Select Filesystem Type", ["1. ext4", "2. btrfs", "3. xfs"]))
        choice = input("\nEnter your choice: ").strip()
        if choice == "1":
            self.fs_type = "ext4"
        elif choice == "2":
            self.fs_type = "btrfs"
        elif choice == "3":
            self.fs_type = "xfs"
        else:
            print("\nInvalid choice. Defaulting to ext4.")
        print(f"\nFilesystem type set to {self.fs_type}")

    def configure_encryption(self):
        """Configures disk encryption."""
        if not self.disk_config:
            print("\nError: Disk configuration must be selected first.")
            return
        try:
            self.disk_encryption = DiskEncryptionMenu(self.disk_config.device_modifications, {}).run()
            print("\nDisk encryption configured.")
        except Exception as e:
            print(f"\nError configuring encryption: {e}")

    def set_hostname(self):
        """Sets the hostname."""
        hostname = input("\nEnter hostname: ").strip()
        if hostname:
            self.hostname = hostname
            print(f"\nHostname set to {self.hostname}")
        else:
            print("\nInvalid hostname. Keeping the default.")

    def add_packages(self):
        """Adds additional packages."""
        package_input = input("\nEnter comma-separated package names: ").strip()
        if package_input:
            self.additional_packages = [pkg.strip() for pkg in package_input.split(",")]
            print(f"\nPackages set to: {', '.join(self.additional_packages)}")
        else:
            print("\nNo packages added.")

    def run_installation(self):
        """Runs the installation process."""
        if not self.disk_config:
            print("\nError: Disk configuration is required.")
            return
        try:
            self.perform_installation()
            print("\nInstallation completed successfully!")
        except Exception as e:
            print(f"\nInstallation failed: {e}")

    def perform_installation(self):
        """Performs the actual installation."""
        mountpoint = Path("/tmp")
        fs_handler = FilesystemHandler(
            self.disk_config, self.disk_encryption, FilesystemType(self.fs_type)
        )
        print("\nFormatting filesystem...")
        fs_handler.perform_filesystem_operations()
        with Installer(
            mountpoint,
            self.disk_config,
            disk_encryption=self.disk_encryption,
            kernels=["linux"],
        ) as installation:
            print("\nMounting layout...")
            installation.mount_ordered_layout()
            print("\nPerforming minimal installation...")
            installation.minimal_installation(hostname=self.hostname)
            print("\nInstalling additional packages...")
            installation.add_additional_packages(self.additional_packages)
            profile_config = ProfileConfiguration(MinimalProfile())
            profile_handler.install_profile_config(installation, profile_config)
            user = User("archinstall", "password", True)
            installation.create_users(user)
        self.run_custom_commands()

    def run_custom_commands(self):
        """Executes custom shell commands post-installation."""
        print("\nRunning custom commands...")
        for cmd in self.custom_commands:
            subprocess.run(cmd, shell=True, check=True)


if __name__ == "__main__":
    check_and_install_dependencies()
    tui = ArchInstallerTUI()
    tui.display_tui()
