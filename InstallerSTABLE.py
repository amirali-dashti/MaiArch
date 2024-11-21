from pathlib import Path
from typing import Any, TYPE_CHECKING, Optional
import subprocess
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


if TYPE_CHECKING:
    _: Any

# Configure logging
logging.basicConfig(level=logging.INFO)

# Constants for argument keys
ARG_HELP = 'help'
ARG_SILENT = 'silent'
ARG_ADVANCED = 'advanced'
ARG_DRY_RUN = 'dry_run'
ARG_DISK_CONFIG = 'disk_config'
ARG_LOCALE_CONFIG = 'locale_config'
ARG_ROOT_PASSWORD = '!root-password'
ARG_USERS = '!users'
ARG_PROFILE_CONFIG = 'profile_config'
ARG_AUDIO_CONFIG = 'audio_config'
ARG_KERNE = 'kernels'
ARG_NTP = 'ntp'
ARG_PACKAGES = 'packages'
ARG_BOOTLOADER = 'bootloader'
ARG_MIRROR_CONFIG = 'mirror_config'
ARG_NETWORK_CONFIG = 'network_config'
ARG_TIMEZONE = 'timezone'
ARG_SERVICES = 'services'
ARG_CUSTOM_COMMANDS = 'custom-commands'
ARG_ENCRYPTION = 'disk_encryption'
ARG_SWAP = 'swap'
ARG_UKI = 'uki'


def exit_if_help_requested() -> None:
    if archinstall.arguments.get(ARG_HELP):
        print("See `man archinstall` for help.")
        exit(0)


def ask_user_questions() -> None:
    """First, we'll ask the user for a bunch of user input."""
    global_menu = GlobalMenu(data_store=archinstall.arguments)
    
    # Enable menu options
    options_to_enable = [
        'archinstall-language',
        'mirror_config',
        'locale_config',
        'disk_config',  # mandatory=True
        'disk_encryption',
        'bootloader',
        'uki',
        'swap',
        'hostname',
        '!root-password',  # mandatory=True
        '!users',  # mandatory=True
        'profile_config',
        'audio_config',
        'kernels',  # mandatory=True
        'packages',
        'network_config',
        'timezone',
        'ntp',
        '__separator__',
        'save_config',
        'install',
        'abort'
    ]
    
    for option in options_to_enable:
        mandatory = option in ['disk_config', '!root-password', '!users', 'kernels']
        global_menu.enable(option, mandatory=mandatory)

    if archinstall.arguments.get(ARG_ADVANCED, False):
        global_menu.enable('parallel downloads')

    global_menu.run()


def perform_installation(mountpoint: Path) -> None:
    """Performs the installation steps on a block device."""
    info('Starting installation...')
    
    disk_config: disk.DiskLayoutConfiguration = archinstall.arguments[ARG_DISK_CONFIG]
    locale_config: locale.LocaleConfiguration = archinstall.arguments[ARG_LOCALE_CONFIG]
    disk_encryption: disk.DiskEncryption = archinstall.arguments.get(ARG_ENCRYPTION, None)

    enable_testing = 'testing' in archinstall.arguments.get('additional-repositories', [])
    enable_multilib = 'multilib' in archinstall.arguments.get('additional-repositories', [])
    run_mkinitcpio = not archinstall.arguments.get(ARG_UKI)

    try:
        with Installer(mountpoint, disk_config, disk_encryption=disk_encryption,
                       kernels=archinstall.arguments.get(ARG_KERNE, ['linux'])) as installation:
            if disk_config.config_type != disk.DiskLayoutType.Pre_mount:
                installation.mount_ordered_layout()

            installation.sanity_check()

            if disk_encryption and disk_encryption.encryption_type != disk.EncryptionType.NoEncryption:
                installation.generate_key_files()

            if mirror_config := archinstall.arguments.get(ARG_MIRROR_CONFIG, None):
                installation.set_mirrors(mirror_config, on_target=False)

            installation.minimal_installation(
                testing=enable_testing,
                multilib=enable_multilib,
                mkinitcpio=run_mkinitcpio,
                hostname=archinstall.arguments.get('hostname', 'archlinux'),
                locale_config=locale_config
            )

            if mirror_config:
                installation.set_mirrors(mirror_config, on_target=True)

            if archinstall.arguments.get(ARG_SWAP):
                installation.setup_swap('zram')

            if archinstall.arguments.get(ARG_BOOTLOADER) == Bootloader.Grub and SysInfo.has_uefi():
                installation.add_additional_packages("grub")

            installation.add_bootloader(
                archinstall.arguments[ARG_BOOTLOADER],
                archinstall.arguments.get(ARG_UKI, False)
            )

            network_config: Optional[NetworkConfiguration] = archinstall.arguments.get(ARG_NETWORK_CONFIG, None)
            if network_config:
                network_config.install_network_config(
                    installation,
                    archinstall.arguments.get(ARG_PROFILE_CONFIG, None)
                )

            if users := archinstall.arguments.get(ARG_USERS, None):
                installation.create_users(users)

            audio_config: Optional[AudioConfiguration] = archinstall.arguments.get(ARG_AUDIO_CONFIG, None)
            if audio_config:
                audio_config.install_audio_config(installation)
            else:
                info("No audio server will be installed")

            if packages := archinstall.arguments.get(ARG_PACKAGES, None):
                installation.add_additional_packages(packages)

            if profile_config := archinstall.arguments.get(ARG_PROFILE_CONFIG, None):
                profile_handler.install_profile_config(installation, profile_config)

            if timezone := archinstall.arguments.get(ARG_TIMEZONE, None):
                installation.set_timezone(timezone)

            if archinstall.arguments.get(ARG_NTP, False):
                installation.activate_time_synchronization()

            if archinstall.accessibility_tools_in_use():
                installation.enable_espeakup()

            if root_pw := archinstall.arguments.get(ARG_ROOT_PASSWORD, None):
                installation.user_set_pw('root', root_pw)

            if profile_config:
                profile_config.profile.post_install(installation)

            if services := archinstall.arguments.get(ARG_SERVICES, None):
                installation.enable_service(services)

            if custom_commands := archinstall.arguments.get(ARG_CUSTOM_COMMANDS, None):
                archinstall.run_custom_user_commands(custom_commands, installation)

            installation.genfstab()
            info("For post-installation tips, see https://wiki.archlinux.org/index.php/Installation_guide#Post-installation")

    except Exception as e:
        logging.error(f"Installation failed: {e}")
        exit(1)

    debug(f"Disk states after installing: {disk.disk_layouts()}")


exit_if_help_requested()

if not archinstall.arguments.get(ARG_SILENT):
    ask_user_questions()

config_output = ConfigurationOutput(archinstall.arguments)

if not archinstall.arguments.get(ARG_SILENT):
    config_output.show()

config_output.save()

if archinstall.arguments.get(ARG_DRY_RUN):
    exit(0)

if not archinstall.arguments.get(ARG_SILENT):
    input(str(_('Press Enter to continue.')))

fs_handler = disk.FilesystemHandler(
    archinstall.arguments[ARG_DISK_CONFIG],
    archinstall.arguments.get(ARG_ENCRYPTION, None)
)

fs_handler.perform_filesystem_operations()
perform_installation(archinstall.storage.get('MOUNT_POINT', Path('/mnt')))
