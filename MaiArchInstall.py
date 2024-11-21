# File: MaiArchInstall.py

from pathlib import Path
import os
import subprocess
import sys

# Check if required dependencies are installed
def check_and_install_dependencies():
    """Check and install required dependencies for the script."""
    dependencies = {
        "python": "Python 3",
        "python-urwid": "Python urwid library",
        "python-archinstall": "ArchInstall library",
    }
    missing = []

    # Check each dependency
    for package, desc in dependencies.items():
        try:
            subprocess.run(["pacman", "-Q", package], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            missing.append(package)

    # Install missing dependencies
    if missing:
        print(f"The following dependencies are missing: {', '.join(missing)}")
        print("Attempting to install them now using pacman...")

        try:
            subprocess.run(["pacman", "-S", "--noconfirm", *missing], check=True)
            print("All dependencies installed successfully.")
        except subprocess.CalledProcessError:
            print(f"Failed to install the following dependencies: {', '.join(missing)}")
            print("Please install them manually and rerun the script.")
            sys.exit(1)
    else:
        print("All required dependencies are already installed.")

# Run dependency check
check_and_install_dependencies()

# The rest of the TUI installer script begins here
import urwid
from archinstall import Installer, ProfileConfiguration, profile_handler, User
from archinstall.default_profiles.minimal import MinimalProfile
from archinstall.lib.disk.device_model import FilesystemType
from archinstall.lib.disk.encryption_menu import DiskEncryptionMenu
from archinstall.lib.disk.filesystem import FilesystemHandler
from archinstall.lib.interactions.disk_conf import select_disk_config


class ArchInstallerTUI:
    def __init__(self):
        self.fs_type = 'ext4'
        self.disk_config = None
        self.disk_encryption = None
        self.hostname = 'minimal-arch'
        self.additional_packages = ['nano', 'wget', 'git']
        self.username = 'archinstall'
        self.password = 'password'
        self.custom_commands = [
            "pacman -Syu --noconfirm",
            "pacman -S htop neofetch --noconfirm"
        ]
        self.root = urwid.Pile([])

    def main_menu(self):
        body = [
            urwid.Text("Welcome to ArchInstaller TUI", align="center"),
            urwid.Divider('-'),
            urwid.Text("Select options to configure your Arch Linux installation."),
            urwid.Divider(),
            urwid.Button("Select Disk Configuration", self.select_disk_config),
            urwid.Button("Set Filesystem Type", self.set_filesystem_type),
            urwid.Button("Configure Encryption", self.configure_encryption),
            urwid.Button("Set Hostname", self.set_hostname),
            urwid.Button("Add Additional Packages", self.add_packages),
            urwid.Button("Run Installation", self.run_installation),
            urwid.Divider(),
            urwid.Button("Quit", self.quit_program),
        ]
        self.root.contents = [(urwid.Pile(body), ('weight', 1))]

    def select_disk_config(self, button):
        try:
            self.disk_config = select_disk_config()
            self.show_message(f"Disk selected: {self.disk_config.device}")
        except Exception as e:
            self.show_message(f"Error selecting disk: {e}")

    def set_filesystem_type(self, button):
        options = ['ext4', 'btrfs', 'xfs']
        menu = urwid.ListBox([urwid.Button(opt, lambda _, fs=opt: self.set_fs_type(fs)) for opt in options])
        self.show_menu(menu, "Select Filesystem Type")

    def set_fs_type(self, fs):
        self.fs_type = fs
        self.show_message(f"Filesystem type set to {fs}")

    def configure_encryption(self, button):
        if not self.disk_config:
            self.show_message("Error: Disk configuration must be selected first.")
            return
        try:
            self.disk_encryption = DiskEncryptionMenu(self.disk_config.device_modifications, {}).run()
            self.show_message("Disk encryption configured.")
        except Exception as e:
            self.show_message(f"Error configuring encryption: {e}")

    def set_hostname(self, button):
        edit = urwid.Edit("Enter hostname: ", self.hostname)
        menu = urwid.Pile([
            edit,
            urwid.Button("Set", lambda _: self.save_hostname(edit.get_edit_text())),
        ])
        self.show_menu(menu, "Set Hostname")

    def save_hostname(self, hostname):
        self.hostname = hostname
        self.show_message(f"Hostname set to {hostname}")

    def add_packages(self, button):
        edit = urwid.Edit("Enter comma-separated package names: ", ', '.join(self.additional_packages))
        menu = urwid.Pile([
            edit,
            urwid.Button("Add", lambda _: self.save_packages(edit.get_edit_text())),
        ])
        self.show_menu(menu, "Add Additional Packages")

    def save_packages(self, packages):
        self.additional_packages = [pkg.strip() for pkg in packages.split(',')]
        self.show_message(f"Packages set to: {', '.join(self.additional_packages)}")

    def run_installation(self, button):
        if not self.disk_config:
            self.show_message("Error: Disk configuration is required.")
            return
        try:
            self.perform_installation()
            self.show_message("Installation completed successfully!")
        except Exception as e:
            self.show_message(f"Installation failed: {e}")

    def perform_installation(self):
        mountpoint = Path('/tmp')
        fs_handler = FilesystemHandler(
            self.disk_config, self.disk_encryption, FilesystemType(self.fs_type)
        )
        self.run_with_progress("Formatting Filesystem", fs_handler.perform_filesystem_operations)
        with Installer(
            mountpoint,
            self.disk_config,
            disk_encryption=self.disk_encryption,
            kernels=['linux']
        ) as installation:
            self.run_with_progress("Mounting Layout", installation.mount_ordered_layout)
            self.run_with_progress(
                "Performing Minimal Installation",
                lambda: installation.minimal_installation(hostname=self.hostname)
            )
            installation.add_additional_packages(self.additional_packages)
            profile_config = ProfileConfiguration(MinimalProfile())
            profile_handler.install_profile_config(installation, profile_config)
            user = User(self.username, self.password, True)
            installation.create_users(user)
        self.post_install_custom_commands()

    def post_install_custom_commands(self):
        """Runs custom commands post-installation."""
        self.run_with_progress(
            "Executing Post-Installation Commands",
            lambda: [subprocess.run(cmd, shell=True, check=True) for cmd in self.custom_commands]
        )

    def run_with_progress(self, label, func):
        """Runs a task with a progress bar."""
        progress = urwid.ProgressBar('pg normal', 'pg complete', current=0, done=10)
        text = urwid.Text(label)
        pile = urwid.Pile([text, progress])
        self.root.contents = [(pile, ('weight', 1))]
        urwid.MainLoop(self.root).draw_screen()
        for i in range(1, 11):
            func()
            progress.set_completion(i)

    def quit_program(self, button):
        raise urwid.ExitMainLoop()

    def show_message(self, message):
        self.root.contents.append((urwid.Text(message), ('weight', 1)))
        self.root.contents.append((urwid.Divider(), ('weight', 1)))

    def show_menu(self, menu, title=""):
        body = [urwid.Text(title), urwid.Divider('-'), menu, urwid.Button("Back", self.main_menu)]
        self.root.contents = [(urwid.Pile(body), ('weight', 1))]

    def run(self):
        self.main_menu()
        urwid.MainLoop(self.root, palette=[('pg normal', 'light gray', 'black'),
                                           ('pg complete', 'black', 'light green'),
                                           ('reversed', 'standout', '')]).run()


if __name__ == "__main__":
    check_and_install_dependencies()
    tui = ArchInstallerTUI()
    tui.run()
