# File: MaiArchInstall.py

from pathlib import Path
import os
import subprocess
import sys
import npyscreen
from archinstall import Installer, ProfileConfiguration, profile_handler, User
from archinstall.default_profiles.minimal import MinimalProfile
from archinstall.lib.disk.device_model import FilesystemType
from archinstall.lib.disk.encryption_menu import DiskEncryptionMenu
from archinstall.lib.disk.filesystem import FilesystemHandler
from archinstall.lib.interactions.disk_conf import select_disk_config

# Check if required dependencies are installed
def check_and_install_dependencies():
    """Check and install required dependencies for the script."""
    dependencies = {
        "python": "Python 3",
        "python-npyscreen": "Python npyscreen library",
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
            subprocess.run(["pacman", "-S", "--noconfirm", *missing], check=True)
            print("All dependencies installed successfully.")
        except subprocess.CalledProcessError:
            print(f"Failed to install: {', '.join(missing)}")
            print("Please install them manually and rerun the script.")
            sys.exit(1)
    else:
        print("All required dependencies are already installed.")

# Run dependency check
check_and_install_dependencies()


class ArchInstallerTUI(npyscreen.NPSAppManaged):
    def onStart(self):
        self.addForm("MAIN", MainForm, name="Arch Installer TUI")


class MainForm(npyscreen.FormBaseNew):
    def create(self):
        self.fs_type = "ext4"
        self.disk_config = None
        self.disk_encryption = None
        self.hostname = "minimal-arch"
        self.additional_packages = ["nano", "wget", "git"]
        self.custom_commands = [
            "pacman -Syu --noconfirm",
            "pacman -S htop neofetch --noconfirm"
        ]

        self.title = self.add(npyscreen.TitleFixedText, name="Arch Installer", value="Welcome to the Arch Installer TUI!")
        self.add(npyscreen.FixedText, value="Please configure your installation below:", editable=False)
        self.add(npyscreen.FixedText, value="(Use Arrow keys to navigate, Enter to select)", editable=False)
        
        self.disk_button = self.add(npyscreen.ButtonPress, name="Select Disk Configuration", when_pressed_function=self.select_disk_config)
        self.fs_button = self.add(npyscreen.ButtonPress, name="Set Filesystem Type", when_pressed_function=self.set_filesystem_type)
        self.encryption_button = self.add(npyscreen.ButtonPress, name="Configure Encryption", when_pressed_function=self.configure_encryption)
        self.hostname_button = self.add(npyscreen.ButtonPress, name="Set Hostname", when_pressed_function=self.set_hostname)
        self.packages_button = self.add(npyscreen.ButtonPress, name="Add Additional Packages", when_pressed_function=self.add_packages)
        self.install_button = self.add(npyscreen.ButtonPress, name="Run Installation", when_pressed_function=self.run_installation)

    def select_disk_config(self):
        try:
            self.disk_config = select_disk_config()
            npyscreen.notify_confirm(f"Disk selected: {self.disk_config.device}", title="Success")
        except Exception as e:
            npyscreen.notify_confirm(f"Error selecting disk: {e}", title="Error")

    def set_filesystem_type(self):
        choices = ["ext4", "btrfs", "xfs"]
        choice = npyscreen.selectOne(choices, title="Select Filesystem Type")
        if choice:
            self.fs_type = choices[choice]
            npyscreen.notify_confirm(f"Filesystem type set to {self.fs_type}", title="Success")

    def configure_encryption(self):
        if not self.disk_config:
            npyscreen.notify_confirm("Disk configuration must be selected first.", title="Error")
            return
        try:
            self.disk_encryption = DiskEncryptionMenu(self.disk_config.device_modifications, {}).run()
            npyscreen.notify_confirm("Disk encryption configured.", title="Success")
        except Exception as e:
            npyscreen.notify_confirm(f"Error configuring encryption: {e}", title="Error")

    def set_hostname(self):
        hostname = npyscreen.notify_input("Enter Hostname:", self.hostname)
        if hostname:
            self.hostname = hostname
            npyscreen.notify_confirm(f"Hostname set to {self.hostname}", title="Success")

    def add_packages(self):
        package_input = npyscreen.notify_input(
            "Enter comma-separated package names:",
            ", ".join(self.additional_packages),
        )
        if package_input:
            self.additional_packages = [pkg.strip() for pkg in package_input.split(",")]
            npyscreen.notify_confirm(f"Packages set to: {', '.join(self.additional_packages)}", title="Success")

    def run_installation(self):
        if not self.disk_config:
            npyscreen.notify_confirm("Disk configuration is required.", title="Error")
            return
        try:
            self.perform_installation()
            npyscreen.notify_confirm("Installation completed successfully!", title="Success")
        except Exception as e:
            npyscreen.notify_confirm(f"Installation failed: {e}", title="Error")

    def perform_installation(self):
        mountpoint = Path("/tmp")
        fs_handler = FilesystemHandler(
            self.disk_config, self.disk_encryption, FilesystemType(self.fs_type)
        )
        fs_handler.perform_filesystem_operations()
        with Installer(
            mountpoint,
            self.disk_config,
            disk_encryption=self.disk_encryption,
            kernels=["linux"],
        ) as installation:
            installation.mount_ordered_layout()
            installation.minimal_installation(hostname=self.hostname)
            installation.add_additional_packages(self.additional_packages)
            profile_config = ProfileConfiguration(MinimalProfile())
            profile_handler.install_profile_config(installation, profile_config)
            user = User("archinstall", "password", True)
            installation.create_users(user)
        self.run_custom_commands()

    def run_custom_commands(self):
        for cmd in self.custom_commands:
            subprocess.run(cmd, shell=True, check=True)


if __name__ == "__main__":
    app = ArchInstallerTUI()
    app.run()
