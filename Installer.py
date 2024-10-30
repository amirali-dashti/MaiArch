from pathlib import Path
from archinstall import Installer, ProfileConfiguration, profile_handler, User
from archinstall.default_profiles.minimal import MinimalProfile
from archinstall.lib.disk.device_model import FilesystemType
from archinstall.lib.disk.encryption_menu import DiskEncryptionMenu
from archinstall.lib.disk.filesystem import FilesystemHandler
from archinstall.lib.interactions.disk_conf import select_disk_config

# Define the filesystem type
fs_type = FilesystemType('ext4')

# Select the disk configuration
disk_config = select_disk_config()

# Prompt for optional disk encryption
data_store = {}
disk_encryption = DiskEncryptionMenu(disk_config.device_modifications, data_store).run()

# Initialize the filesystem handler
fs_handler = FilesystemHandler(disk_config, disk_encryption)

# Execute filesystem operations (formats and prepares partitions)
fs_handler.perform_filesystem_operations()

# Set the mount point for the installation
mountpoint = Path('/mnt')  # Adjust mountpoint if needed

# Perform the installation
with Installer(
    mountpoint,
    disk_config,
    disk_encryption=disk_encryption,
    kernels=['linux']
) as installation:
    installation.mount_ordered_layout()
    installation.minimal_installation(hostname='minimal-arch')
    installation.add_additional_packages(['nano', 'wget', 'git'])

    # Install a minimal profile
    profile_config = ProfileConfiguration(MinimalProfile())
    profile_handler.install_profile_config(installation, profile_config)

    # Create a user with sudo privileges
    user = User('archinstall', 'password', True)
    installation.create_users(user)

print("Installation complete. You may now reboot.")
