##############################################################################
# Mai Bloom OS Installer - Using Archinstall Library Directly
# Based on user-provided snippet structure and stability preference.
##############################################################################

import sys
import os
import traceback
import time
import json # For lsblk only
import logging # Now imported globally
from pathlib import Path
from typing import Any, TYPE_CHECKING, Optional, Dict, List, Union # Type hinting

# --- PyQt5 Imports ---
from PyQt5.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout,
                             QLabel, QLineEdit, QPushButton, QComboBox,
                             QMessageBox, QFileDialog, QTextEdit, QCheckBox,
                             QGroupBox, QGridLayout, QSplitter)
from PyQt5.QtCore import QThread, pyqtSignal, Qt

# --- Attempt to import Archinstall components ---
# This section tries to import necessary archinstall components.
# If these imports fail, the installer cannot function with the real library.
# User MUST verify these imports match their installed archinstall version.
ARCHINSTALL_LIBRARY_AVAILABLE = False
ARCHINSTALL_IMPORT_ERROR = None
try:
    import archinstall
    from archinstall import info, debug, SysInfo # Logging/SysInfo funcs
    from archinstall.lib import locale, disk    # Core modules for config objects/handlers
    from archinstall.lib.configuration import ConfigurationOutput # Potentially useful
    from archinstall.lib.installer import Installer             # Core installer class
    from archinstall.lib.models import ProfileConfiguration, User, DiskEncryption, AudioConfiguration, Bootloader, Profile # Config models
    from archinstall.lib.models.network_configuration import NetworkConfiguration
    from archinstall.lib.profile.profiles_handler import profile_handler # Profile handling logic
    from archinstall.lib.exceptions import ArchinstallError, UserInteractionRequired # Specific exceptions

    # --- Constants for archinstall.arguments keys (from user snippet) ---
    # It's safer to define these once at the top level.
    ARG_DISK_CONFIG = 'disk_config'; ARG_LOCALE_CONFIG = 'locale_config'; ARG_ROOT_PASSWORD = '!root-password'
    ARG_USERS = '!users'; ARG_PROFILE_CONFIG = 'profile_config'; ARG_AUDIO_CONFIG = 'audio_config'
    ARG_KERNE = 'kernels'; ARG_NTP = 'ntp'; ARG_PACKAGES = 'packages'; ARG_BOOTLOADER = 'bootloader'
    ARG_MIRROR_CONFIG = 'mirror_config'; ARG_NETWORK_CONFIG = 'network_config'; ARG_TIMEZONE = 'timezone'
    ARG_SERVICES = 'services'; ARG_CUSTOM_COMMANDS = 'custom-commands'; ARG_ENCRYPTION = 'disk_encryption'
    ARG_SWAP = 'swap'; ARG_UKI = 'uki'; ARG_HOSTNAME = 'hostname'

    # Initialize global state containers if archinstall relies on them
    if not hasattr(archinstall, 'arguments'): archinstall.arguments = {}
    if not hasattr(archinstall, 'storage'): archinstall.storage = {}
    archinstall.storage['MOUNT_POINT'] = Path('/mnt/maibloom_install') # Set default mount point

    ARCHINSTALL_LIBRARY_AVAILABLE = True
    logging.info("Successfully imported Archinstall library components.")

except ImportError as e:
    ARCHINSTALL_IMPORT_ERROR = e
    logging.error(f"Failed to import required archinstall modules: {e}")
    # Define dummy exception/classes for GUI structure if imports fail
    class ArchinstallError(Exception): pass
    class UserInteractionRequired(Exception): pass
    class Bootloader: Grub = 'grub'; SystemdBoot = 'systemd-boot' # Dummy enum values
    class DiskLayoutType: Default = 'Default'; Pre_mount = 'Pre_mount' # Dummy enum values
    class WipeMode: Secure = 'Secure' # Dummy enum value
    class DiskLayoutConfiguration: pass
    class LocaleConfiguration: pass
    class ProfileConfiguration: pass
    class User: pass
    class DiskEncryption: pass
    class AudioConfiguration: pass
    class NetworkConfiguration: pass
    class Installer: pass # Dummy class
    class FilesystemHandler: pass # Dummy class
    class profile_handler: pass # Dummy class
    class SysInfo: @staticmethod def has_uefi(): return os.path.exists("/sys/firmware/efi") # Mock check
    # Dummy args if imports fail
    ARG_DISK_CONFIG = 'disk_config'; ARG_LOCALE_CONFIG = 'locale_config'; ARG_ROOT_PASSWORD = '!root-password'; ARG_USERS = '!users'; ARG_PROFILE_CONFIG = 'profile_config'; ARG_HOSTNAME = 'hostname'; ARG_PACKAGES = 'packages'; ARG_BOOTLOADER = 'bootloader'; ARG_TIMEZONE = 'timezone'; ARG_KERNE = 'kernels'; ARG_NTP = 'ntp'; ARG_SWAP = 'swap'; ARG_ENCRYPTION = 'disk_encryption'


# --- App Configuration ---
APP_CATEGORIES = {
    "Daily Use": ["firefox", "vlc", "gwenview", "okular", "libreoffice-still", "ark", "kate"],
    "Programming": ["git", "code", "python", "gcc", "gdb", "base-devel"],
    "Gaming": ["steam", "lutris", "wine", "noto-fonts-cjk"],
    "Education": ["gcompris-qt", "kgeography", "stellarium", "kalgebra"]
}
DEFAULT_DESKTOP_ENVIRONMENT_PROFILE = "kde" # Mai Bloom OS default
MOUNT_POINT = Path('/mnt/maibloom_install') # Ensure consistent definition

def check_root(): return os.geteuid() == 0


# --- Installer Engine Thread (Uses Archinstall Library Based on User Snippet) ---
class InstallerEngineThread(QThread):
    """
    This thread orchestrates the installation using archinstall library calls.
    It relies on archinstall.arguments being correctly populated by the GUI.
    """
    installation_finished = pyqtSignal(bool, str) # bool: success, str: message
    installation_log = pyqtSignal(str, str)       # str: message, str: level

    def __init__(self): # No longer needs arguments if reading global dict
        super().__init__()
        self._running = True

    def log(self, message, level="INFO"):
        """Sends a log message to the GUI thread."""
        # Avoid direct GUI updates from worker thread; use signals.
        self.installation_log.emit(str(message), level)

    def stop(self):
        """Requests the installation process to stop."""
        self.log("Stop request received. Installation will halt before next major step.", "WARN")
        self._running = False

    # perform_installation logic adapted from user's snippet
    def _perform_installation_steps(self, mountpoint: Path) -> None:
        """Performs the installation steps using archinstall library calls."""
        # This method contains the core logic adapted from the user's code snippet
        self.log('Starting installation steps using Archinstall library...')

        # Retrieve config objects/values from the global arguments dict
        # The gather_settings function in the GUI must populate these correctly!
        # Added .get() for safety, but KeyError should be caught below if mandatory args missing.
        disk_config = archinstall.arguments.get(ARG_DISK_CONFIG)
        locale_config = archinstall.arguments.get(ARG_LOCALE_CONFIG)
        disk_encryption = archinstall.arguments.get(ARG_ENCRYPTION)
        hostname = archinstall.arguments.get(ARG_HOSTNAME, 'maibloom-os')
        users = archinstall.arguments.get(ARG_USERS, [])
        root_pw = archinstall.arguments.get(ARG_ROOT_PASSWORD)
        profile_config = archinstall.arguments.get(ARG_PROFILE_CONFIG)
        additional_packages = archinstall.arguments.get(ARG_PACKAGES, [])
        bootloader_choice = archinstall.arguments.get(ARG_BOOTLOADER)
        kernels = archinstall.arguments.get(ARG_KERNE, ['linux'])
        timezone = archinstall.arguments.get(ARG_TIMEZONE)
        enable_ntp = archinstall.arguments.get(ARG_NTP, True)
        enable_swap = archinstall.arguments.get(ARG_SWAP, True)
        audio_config = archinstall.arguments.get(ARG_AUDIO_CONFIG)
        network_config = archinstall.arguments.get(ARG_NETWORK_CONFIG)
        services_to_enable = archinstall.arguments.get(ARG_SERVICES)
        custom_commands_to_run = archinstall.arguments.get(ARG_CUSTOM_COMMANDS)

        # Check for essential missing arguments (should be caught by gather_settings ideally)
        if not all([disk_config, locale_config, users, root_pw, profile_config, bootloader_choice]):
             raise ArchinstallError("Core configuration arguments missing in archinstall.arguments.")

        enable_testing = 'testing' in archinstall.arguments.get('additional-repositories', [])
        enable_multilib = 'multilib' in archinstall.arguments.get('additional-repositories', [])
        run_mkinitcpio = not archinstall.arguments.get(ARG_UKI, False)

        self.log(f"Initializing Installer for mountpoint {mountpoint}...")
        # Use the Installer class as a context manager
        with Installer(mountpoint, disk_config, disk_encryption=disk_encryption, kernels=kernels) as installation:
            self.log("Installer context entered.")
            # Check stop flag frequently
            if not self._running: raise InterruptedError("Stopped before mounting.")

            # Mount filesystem if not pre-mounted
            # Assumes disk_config object has `config_type` attribute and DiskLayoutType enum exists
            if disk_config.config_type != disk.DiskLayoutType.Pre_mount:
                 self.log("Mounting configured layout...")
                 # This call requires DiskLayoutConfiguration to be fully implemented by user
                 installation.mount_ordered_layout()
            else:
                 self.log("Disk layout type is Pre_mount, skipping mount_ordered_layout.")

            if not self._running: raise InterruptedError("Stopped after mounting attempt.")

            self.log("Performing sanity checks...")
            installation.sanity_check()

            if disk_encryption and disk_encryption.encryption_type != disk.EncryptionType.NoEncryption:
                self.log("Handling disk encryption setup...")
                installation.generate_key_files() # Requires correctly configured DiskEncryption object

            # Mirror configuration
            if mirror_config := archinstall.arguments.get(ARG_MIRROR_CONFIG):
                 self.log("Setting mirrors on host...")
                 installation.set_mirrors(mirror_config, on_target=False)

            if not self._running: raise InterruptedError("Stopped before minimal installation.")

            # Minimal Installation (Base system + essential config)
            self.log("Performing minimal installation (pacstrap base, locale, hostname)...")
            # This requires LocaleConfiguration object
            installation.minimal_installation(
                testing=enable_testing, multilib=enable_multilib,
                mkinitcpio=run_mkinitcpio, hostname=hostname, locale_config=locale_config
            )
            self.log("Minimal installation complete.")

            if not self._running: raise InterruptedError("Stopped after minimal installation.")

            # Set mirrors on target system
            if mirror_config:
                self.log("Setting mirrors on target system...")
                installation.set_mirrors(mirror_config, on_target=True)

            # Swap setup
            if enable_swap:
                self.log("Setting up swap (zram)...")
                installation.setup_swap('zram') # Hardcoded to zram based on user snippet

            # Bootloader setup
            self.log(f"Adding bootloader: {bootloader_choice.value if hasattr(bootloader_choice, 'value') else bootloader_choice}")
            # Add specific package if GRUB on UEFI
            if bootloader_choice == Bootloader.Grub and SysInfo.has_uefi():
                self.log("Ensuring GRUB package installed for UEFI...")
                installation.add_additional_packages("grub")
            installation.add_bootloader(bootloader_choice, archinstall.arguments.get(ARG_UKI, False))
            self.log("Bootloader setup complete.")

            if not self._running: raise InterruptedError("Stopped after bootloader.")

            # Network Configuration
            if network_config:
                self.log("Configuring network...")
                network_config.install_network_config(installation, profile_config)
            else:
                self.log("Skipping network configuration (relying on NetworkManager package).", "INFO")

            # User Creation (requires list of User objects)
            if users:
                self.log(f"Creating users...")
                installation.create_users(users)
            else:
                 self.log("No users configured.", "WARN")

            # Audio Configuration
            if audio_config:
                self.log(f"Configuring audio...")
                audio_config.install_audio_config(installation)
            else:
                self.log("Skipping audio configuration.", "INFO")

            # Install Additional Packages
            if additional_packages:
                self.log(f"Installing {len(additional_packages)} additional packages...")
                installation.add_additional_packages(additional_packages)

            # Install Profile (e.g., KDE) - requires ProfileConfiguration object
            if profile_config:
                profile_display_name = getattr(getattr(profile_config, 'profile', None), 'name', 'N/A')
                self.log(f"Installing profile: {profile_display_name}...")
                # profile_handler needs correct ProfileConfiguration object
                profile_handler.install_profile_config(installation, profile_config)
                self.log("Profile installation step complete.")
            else:
                 self.log("No profile configuration provided.", "WARN")


            if not self._running: raise InterruptedError("Stopped after profile install.")

            # Timezone
            if timezone:
                self.log(f"Setting timezone: {timezone}")
                installation.set_timezone(timezone)

            # NTP
            if enable_ntp:
                self.log("Enabling NTP time synchronization...")
                installation.activate_time_synchronization()

            # Root Password
            if root_pw:
                self.log("Setting root password...")
                installation.user_set_pw('root', root_pw)
            else:
                 self.log("Root password not set!", "WARN")

            # Profile Post-Install hooks (requires valid profile object in profile_config)
            if profile_config and hasattr(profile_config, 'profile') and profile_config.profile:
                 self.log(f"Running post-install hooks for profile {profile_config.profile.name}...")
                 # This requires profile_config to be a valid object with a profile attribute that has a post_install method
                 profile_config.profile.post_install(installation)

            # Enable Additional Services
            if services_to_enable:
                self.log(f"Enabling services: {services_to_enable}")
                installation.enable_service(services_to_enable) # Assumes list of strings

            # Custom Commands
            if custom_commands_to_run:
                self.log("Running custom commands...")
                archinstall.run_custom_user_commands(custom_commands_to_run, installation)

            if not self._running: raise InterruptedError("Stopped before final steps.")

            # Final Steps
            self.log("Generating fstab...")
            installation.genfstab() # Generate final fstab
            self.log("fstab generated.")

            # End of Installer context manager
            self.log("Installer context exited.")
        
        # End of with block, Installer __exit__ might handle unmounting etc.
        self.log("Installation logic within 'perform_installation' finished.")


    def run(self):
        """Main thread execution: handles FS operations then calls installation."""
        mount_point = archinstall.storage.get('MOUNT_POINT', MOUNT_POINT) # Use configured mount point

        try:
            if not ARCHINSTALL_LIBRARY_AVAILABLE:
                 raise ArchinstallError(f"Archinstall library failed to import: {ARCHINSTALL_IMPORT_ERROR}")

            self.log("Installation process starting in background thread...")
            if not self._running: raise InterruptedError("Stopped before filesystem operations.")

            # --- Filesystem Operations ---
            # This requires ARG_DISK_CONFIG and ARG_ENCRYPTION to be correctly populated
            # in archinstall.arguments with objects of the expected types.
            self.log("Initializing Filesystem Handler...")
            fs_handler = disk.FilesystemHandler(
                archinstall.arguments[ARG_DISK_CONFIG],
                archinstall.arguments.get(ARG_ENCRYPTION, None)
            )
            self.log("Performing filesystem operations (formatting)...")
            # This call performs the mkfs, mkswap operations based on DiskLayoutConfiguration
            fs_handler.perform_filesystem_operations() 
            self.log("Filesystem operations complete.")

            if not self._running: raise InterruptedError("Stopped after formatting.")

            # --- Perform Installation Steps ---
            # This calls the main installation logic using the Installer class
            self._perform_installation_steps(mount_point) 

            # If we reach here without exceptions, it was successful
            self.log("Installation process completed successfully!")
            self.installation_finished.emit(True, f"Mai Bloom OS ({DEFAULT_DESKTOP_ENVIRONMENT_PROFILE}) installed successfully!")

        # --- Error Handling ---
        except InterruptedError as e:
            self.log(f"Installation process was interrupted: {e}", "WARN")
            self.installation_finished.emit(False, f"Installation interrupted by user.")
        except ArchinstallError as e: 
            self.log(f"Archinstall Library Error: {e}", "ERROR")
            self.log(traceback.format_exc(), "ERROR")
            self.installation_finished.emit(False, f"Installation failed: {e}")
        except KeyError as e: 
            self.log(f"Configuration key missing during installation: {e}", "ERROR")
            self.log(traceback.format_exc(), "ERROR")
            self.installation_finished.emit(False, f"Configuration Error: Missing key '{e}' in archinstall.arguments")
        except Exception as e: # General catch-all
            self.log(f"An unexpected critical error occurred: {type(e).__name__}: {e}", "CRITICAL_ERROR")
            self.log(traceback.format_exc(), "CRITICAL_ERROR")
            self.installation_finished.emit(False, f"A critical error occurred: {e}")
        finally:
            # Unmounting should ideally be handled by the Installer context manager's __exit__
            # or called explicitly if needed, but can be complex to do safely here.
            self.log("InstallerEngineThread finished execution.", "INFO")


# --- Main Application Window (GUI using PyQt5) ---
class MaiBloomInstallerApp(QWidget):
    """Main GUI Window for the installer."""
    
    def __init__(self):
        super().__init__()
        # self.installation_settings_for_gui = {} # Internal state if needed
        self.installer_thread = None # Worker thread reference
        self.init_ui()
        self.update_log_output("Welcome to Mai Bloom OS Installer!")
        
        # Initial check for library availability
        if not ARCHINSTALL_LIBRARY_AVAILABLE:
             self.handle_library_load_error()
        else:
             self.update_log_output("Archinstall library loaded successfully.")
             self.trigger_disk_scan() # Trigger initial scan

    def handle_library_load_error(self):
        """Disables UI elements and shows error if library failed to load."""
        self.update_log_output(f"CRITICAL ERROR: Archinstall library not loaded: {ARCHINSTALL_IMPORT_ERROR}", "ERROR")
        QMessageBox.critical(self, "Startup Error", 
                             f"Failed to load essential Archinstall library components:\n{ARCHINSTALL_IMPORT_ERROR}\n\n"
                             "Please ensure Archinstall is correctly installed for the Python environment and accessible.\n"
                             "The installer cannot function.")
        self.install_button.setEnabled(False)
        self.scan_disks_button.setEnabled(False)
        # Disable other input widgets
        for child in self.findChildren(QWidget):
             if isinstance(child, (QLineEdit, QComboBox, QCheckBox, QPushButton)):
                  child.setEnabled(False)

    def init_ui(self):
        """Sets up the GUI widgets and layouts."""
        self.setWindowTitle(f'Mai Bloom OS Installer ({DEFAULT_DESKTOP_ENVIRONMENT_PROFILE} via Archinstall Lib)')
        self.setGeometry(100, 100, 850, 700)
        overall_layout = QVBoxLayout(self) # Main layout for the window

        # --- Top Title ---
        title_label = QLabel(f"<b>Install Mai Bloom OS ({DEFAULT_DESKTOP_ENVIRONMENT_PROFILE})</b>")
        title_label.setAlignment(Qt.AlignCenter)
        overall_layout.addWidget(title_label)
        overall_layout.addWidget(QLabel("<small>This installer uses the <b>archinstall</b> Python library directly for setup.</small>"))
        
        # --- Main Area (Splitter: Controls | Log) ---
        splitter = QSplitter(Qt.Horizontal)
        overall_layout.addWidget(splitter)

        # --- Left Pane: Controls ---
        controls_widget = QWidget()
        controls_layout = QVBoxLayout(controls_widget)

        # GroupBox 1: Disk Setup
        disk_group = QGroupBox("1. Disk Selection & Preparation")
        disk_layout_vbox = QVBoxLayout()
        self.scan_disks_button = QPushButton("Scan for Disks")
        self.scan_disks_button.setToolTip("Scan the system for installable disk drives using archinstall library.")
        self.scan_disks_button.clicked.connect(self.trigger_disk_scan)
        disk_layout_vbox.addWidget(self.scan_disks_button)
        self.disk_combo = QComboBox()
        self.disk_combo.setToolTip("Select the target disk for installation.\nEnsure this is the correct disk!")
        disk_layout_vbox.addLayout(self.create_form_row("Target Disk:", self.disk_combo))
        self.wipe_disk_checkbox = QCheckBox("Wipe disk & auto-configure standard layout")
        self.wipe_disk_checkbox.setChecked(True)
        self.wipe_disk_checkbox.setToolTip("IMPORTANT: This option attempts to instruct archinstall library to ERASE the selected disk\n"
                                           "and create a standard partition layout (e.g., EFI, Swap, Root).\n"
                                           "This requires correct implementation of DiskLayoutConfiguration in gather_settings().")
        disk_layout_vbox.addWidget(self.wipe_disk_checkbox)
        disk_group.setLayout(disk_layout_vbox)
        controls_layout.addWidget(disk_group)

        # GroupBox 2: System & User Configuration
        system_group = QGroupBox("2. System & User Details")
        system_layout_grid = QGridLayout()
        self.hostname_input = QLineEdit("maibloom-os")
        self.hostname_input.setToolTip("Set the computer's network name (e.g., mypc).")
        system_layout_grid.addWidget(QLabel("Hostname:"), 0, 0); system_layout_grid.addWidget(self.hostname_input, 0, 1)
        self.username_input = QLineEdit("maiuser")
        self.username_input.setToolTip("Enter the desired username for your main account.")
        system_layout_grid.addWidget(QLabel("Username:"), 1, 0); system_layout_grid.addWidget(self.username_input, 1, 1)
        self.password_input = QLineEdit()
        self.password_input.setPlaceholderText("Enter password (used for User & Root)"); self.password_input.setEchoMode(QLineEdit.Password)
        self.password_input.setToolTip("Set the password for your user account.\nThis password will ALSO be set for the 'root' administrator account.")
        system_layout_grid.addWidget(QLabel("Password (User+Root):"), 2, 0); system_layout_grid.addWidget(self.password_input, 2, 1)
        self.locale_input = QLineEdit("en_US.UTF-8")
        self.locale_input.setToolTip("Set the system language and encoding (e.g., en_US.UTF-8, fr_FR.UTF-8).")
        system_layout_grid.addWidget(QLabel("Locale:"), 3,0); system_layout_grid.addWidget(self.locale_input, 3,1)
        self.kb_layout_input = QLineEdit("us")
        self.kb_layout_input.setToolTip("Set the keyboard layout for the console (e.g., us, uk, de_nodeadkeys).")
        system_layout_grid.addWidget(QLabel("Keyboard Layout:"), 4,0); system_layout_grid.addWidget(self.kb_layout_input, 4,1)
        self.timezone_input = QLineEdit("UTC")
        self.timezone_input.setToolTip("Set the system timezone (e.g., UTC, America/New_York, Europe/Paris).\nUse format Region/City.")
        system_layout_grid.addWidget(QLabel("Timezone:"), 5,0); system_layout_grid.addWidget(self.timezone_input, 5,1)
        system_group.setLayout(system_layout_grid)
        controls_layout.addWidget(system_group)
        
        # GroupBox 3: Additional Applications
        app_group = QGroupBox(f"3. Additional Applications (Optional)")
        app_layout_grid = QGridLayout()
        self.app_category_checkboxes = {}
        row, col = 0,0
        for cat_name in APP_CATEGORIES.keys():
            self.app_category_checkboxes[cat_name] = QCheckBox(f"{cat_name}")
            pkg_list_tooltip = f"Install: {', '.join(APP_CATEGORIES[cat_name][:4])}" # Show first few packages
            if len(APP_CATEGORIES[cat_name]) > 4: pkg_list_tooltip += "..."
            self.app_category_checkboxes[cat_name].setToolTip(pkg_list_tooltip)
            app_layout_grid.addWidget(self.app_category_checkboxes[cat_name], row, col)
            col +=1
            if col > 1: col = 0; row +=1 # Arrange in 2 columns
        app_group.setLayout(app_layout_grid)
        controls_layout.addWidget(app_group)
        
        # Add stretch to push controls towards the top
        controls_layout.addStretch(1) 
        # Add the controls widget pane to the splitter
        splitter.addWidget(controls_widget)

        # --- Right Pane: Log Output ---
        log_group_box = QGroupBox("Installation Log")
        log_layout_vbox = QVBoxLayout()
        self.log_output = QTextEdit()
        self.log_output.setReadOnly(True)
        self.log_output.setLineWrapMode(QTextEdit.NoWrap) 
        self.log_output.setStyleSheet("font-family: monospace; background-color: #f0f0f0;") # Monospace font, light background
        log_layout_vbox.addWidget(self.log_output)
        log_group_box.setLayout(log_layout_vbox)
        # Add the log widget pane to the splitter
        splitter.addWidget(log_group_box)
        
        # Set initial size ratio for the panes
        splitter.setSizes([400, 450]) 
        
        # --- Bottom: Install Button ---
        self.install_button = QPushButton(f"Install Mai Bloom OS ({DEFAULT_DESKTOP_ENVIRONMENT_PROFILE})")
        self.install_button.setStyleSheet("background-color: lightgreen; padding: 10px; font-weight: bold; border-radius: 5px;")
        self.install_button.setToolTip("Begin the installation process using the configured settings.")
        self.install_button.clicked.connect(self.start_installation)
        # Center the button using a QHBoxLayout with stretches
        button_layout = QHBoxLayout()
        button_layout.addStretch()
        button_layout.addWidget(self.install_button)
        button_layout.addStretch()
        overall_layout.addLayout(button_layout)

    def create_form_row(self, label_text, widget):
        """Helper method to create a standard Label + Widget horizontal layout."""
        row_layout = QHBoxLayout()
        label = QLabel(label_text)
        label.setFixedWidth(120) # Consistent label width for alignment
        row_layout.addWidget(label)
        row_layout.addWidget(widget)
        return row_layout

    def trigger_disk_scan(self):
        """Initiates disk scan using archinstall library helper."""
        if not ARCHINSTALL_LIBRARY_AVAILABLE:
            self.update_log_output("Disk Scan unavailable: Archinstall library not loaded.", "ERROR")
            return
            
        self.update_log_output("GUI: Requesting disk scan via archinstall library...")
        self.scan_disks_button.setEnabled(False) # Disable button during scan
        try:
            # --- USER ACTION REQUIRED ---
            # Replace the placeholder logic below with DIRECT calls to archinstall's
            # disk listing function(s). This code needs to run SYNCHRONOUSLY here
            # or be moved to a separate short-lived thread if the library call is slow.
            
            # Placeholder/Mock Logic (REMOVE THIS SECTION WHEN IMPLEMENTING REAL SCAN)
            processed_disks = {}
            self.update_log_output(" (Using placeholder disk scan logic - USER MUST REPLACE)", "WARN")
            if 'disk_module_actual' in globals() and disk_module_actual: # Use the potentially mocked or real module
                 block_devices = disk_module_actual.get_all_blockdevices() 
                 # Filtering logic (adapt attributes to real BlockDevice object)
                 for device in block_devices:
                     try:
                         dev_path_str = str(getattr(device,'path', 'N/A'))
                         dev_type = str(getattr(device, 'type', 'unknown')).lower()
                         dev_ro = getattr(device, 'read_only', True)
                         dev_pkname = getattr(device, 'pkname', None)
                         dev_model = getattr(device, 'model', 'Unknown Model')
                         dev_size_bytes = int(getattr(device, 'size', 0))
                         if dev_type == 'disk' and not dev_ro and not dev_pkname and dev_size_bytes >= 20 * (1024**3):
                              processed_disks[dev_path_str] = {"model": dev_model, "size": f"{dev_size_bytes / (1024**3):.2f} GB", "path": dev_path_str}
                     except Exception as inner_e:
                          self.update_log_output(f"Error processing device {getattr(device, 'path', 'N/A')}: {inner_e}", "WARN")
            # --- End Placeholder Logic ---
            
            # Assuming the real call populates processed_disks directly or you adapt it
            self.on_disk_scan_complete(processed_disks) 

        except Exception as e:
            self.update_log_output(f"Disk Scan Error: {e}", "ERROR")
            self.update_log_output(traceback.format_exc(), "ERROR")
            self.on_disk_scan_complete({}) # Send empty results on error
            QMessageBox.critical(self, "Disk Scan Error", f"Failed to scan disks using archinstall library: {e}")
        finally:
            self.scan_disks_button.setEnabled(True) # Re-enable button

    def on_disk_scan_complete(self, disks_data: Dict[str, Dict]):
        """Slot to handle the result of the disk scan signal or direct call."""
        self.update_log_output(f"GUI: Disk scan finished. Populating {len(disks_data)} suitable disk(s).")
        self.disk_combo.clear()
        if disks_data:
            for path_key, info_dict in sorted(disks_data.items()): # Sort by path
                display_text = f"{path_key} - {info_dict.get('model', 'N/A')} ({info_dict.get('size', 'N/A')})"
                self.disk_combo.addItem(display_text, userData=path_key) # Store path in userData
        else:
            self.update_log_output("GUI: No suitable disks found by scan.", "WARN")
            # Optionally show a warning popup if no disks are found after scan
            # QMessageBox.warning(self, "Disk Scan", "No suitable installation disks detected.")

    def update_log_output(self, message: str, level: str = "INFO"):
        """Appends a message to the GUI log view, adding a level prefix."""
        prefix = "" if level == "INFO" else f"[{level}] "
        self.log_output.append(prefix + message)
        self.log_output.ensureCursorVisible() # Auto-scroll
        # Process events sparingly to keep UI responsive but avoid slowdown
        if level not in ["DEBUG", "CMD_OUT", "CMD_ERR", "CMD"]: 
             QApplication.processEvents()

    def gather_settings_and_populate_args(self) -> bool:
        """
        Gathers settings from GUI, validates them, and populates the global
        archinstall.arguments dictionary with the necessary objects/structures.
        Returns True if successful, False otherwise.

        !!! CRITICAL USER IMPLEMENTATION AREA !!!
        This function requires detailed knowledge of the target archinstall version's
        internal API to correctly instantiate configuration objects (DiskLayoutConfiguration,
        LocaleConfiguration, User, ProfileConfiguration, etc.).
        The current implementation uses placeholders that MUST be replaced.
        """
        self.update_log_output("Gathering settings and preparing archinstall arguments...")
        # Use a temporary dict to gather raw GUI values
        gui_settings: Dict[str, Any] = {}
        
        # --- Disk ---
        selected_disk_index = self.disk_combo.currentIndex()
        if selected_disk_index < 0: QMessageBox.warning(self, "Input Error", "Please select a target disk."); return False
        target_disk_path_str = self.disk_combo.itemData(selected_disk_index)
        if not target_disk_path_str: QMessageBox.warning(self, "Input Error", "Invalid disk selected."); return False
        gui_settings["target_disk_path"] = Path(target_disk_path_str) # Store as Path object
        gui_settings["wipe_disk"] = self.wipe_disk_checkbox.isChecked()

        # --- System & User ---
        gui_settings["hostname"] = self.hostname_input.text().strip()
        gui_settings["username"] = self.username_input.text().strip()
        gui_settings["password"] = self.password_input.text() # User & Root password
        gui_settings["locale"] = self.locale_input.text().strip()
        gui_settings["kb_layout"] = self.kb_layout_input.text().strip()
        gui_settings["timezone"] = self.timezone_input.text().strip()
        
        # --- Basic Input Validation ---
        if not gui_settings["hostname"]: QMessageBox.warning(self, "Input Error", "Hostname cannot be empty."); return False
        if not gui_settings["username"]: QMessageBox.warning(self, "Input Error", "Username cannot be empty."); return False
        # Basic check, consider adding complexity rules if desired
        if not gui_settings["password"]: QMessageBox.warning(self, "Input Error", "Password cannot be empty."); return False 
        if not gui_settings["locale"]: QMessageBox.warning(self, "Input Error", "Locale cannot be empty."); return False
        if not gui_settings["kb_layout"]: QMessageBox.warning(self, "Input Error", "Keyboard Layout cannot be empty."); return False
        if not gui_settings["timezone"]: QMessageBox.warning(self, "Input Error", "Timezone cannot be empty."); return False
        # Add regex validation for hostname, username if needed

        # --- Profile & Packages ---
        gui_settings["profile_name"] = DEFAULT_DESKTOP_ENVIRONMENT_PROFILE # Fixed profile
        additional_packages = []
        for cat_name, checkbox_widget in self.app_category_checkboxes.items():
            if checkbox_widget.isChecked():
                additional_packages.extend(APP_CATEGORIES.get(cat_name, []))
        base_essentials = ["sudo", "nano"] # Add some basics
        additional_packages = list(set(additional_packages + base_essentials))
        gui_settings["additional_packages"] = additional_packages

        # --- Populate archinstall.arguments (Critical Section) ---
        try:
            if not ARCHINSTALL_LIBRARY_AVAILABLE:
                 raise ArchinstallError("Cannot populate arguments, library not loaded.")
                 
            args = archinstall.arguments # Get reference to the global dictionary
            args.clear() # Clear previous arguments if any

            # --- Simple Arguments ---
            args[ARG_HOSTNAME] = gui_settings["hostname"]
            args[ARG_ROOT_PASSWORD] = gui_settings["password"]
            args[ARG_TIMEZONE] = gui_settings["timezone"]
            args[ARG_KERNE] = ['linux'] 
            args[ARG_NTP] = True
            args[ARG_SWAP] = True 
            args[ARG_PACKAGES] = gui_settings["additional_packages"]
            
            is_efi = SysInfo.has_uefi() # Use SysInfo if available
            args[ARG_BOOTLOADER] = models.Bootloader.SystemdBoot if is_efi else models.Bootloader.Grub
            args[ARG_UKI] = False # Default, set based on GUI/config if needed
            
            # --- Complex Arguments Requiring Object Instantiation ---
            # !!! USER ACTION REQUIRED: Replace placeholders below !!!

            # 1. LocaleConfiguration
            self.log("Setting Locale Config... (USER MUST VERIFY/IMPLEMENT)", "WARN")
            # Research: archinstall.lib.locale.LocaleConfiguration.__init__(self, ...)
            args[ARG_LOCALE_CONFIG] = locale.LocaleConfiguration(
                kb_layout=gui_settings["kb_layout"], 
                sys_lang=gui_settings["locale"], 
                sys_enc='UTF-8' # Usually UTF-8
            )
            
            # 2. User list (list of models.User objects)
            self.log("Setting User Config... (USER MUST VERIFY/IMPLEMENT)", "WARN")
            # Research: archinstall.lib.models.User.__init__(self, ...)
            args[ARG_USERS] = [
                models.User(
                    gui_settings["username"], 
                    gui_settings["password"], 
                    sudo=True # Assume primary user needs sudo
                )
            ]
            
            # 3. ProfileConfiguration
            self.log(f"Setting Profile Config ({gui_settings['profile_name']})... (USER MUST VERIFY/IMPLEMENT)", "WARN")
            # Research: archinstall.lib.models.ProfileConfiguration and archinstall.lib.profile.profiles_handler
            # This might involve getting a Profile object first.
            # profile_object = profile_handler.get_profile(gui_settings["profile_name"]) # Hypothetical
            # if not profile_object: raise ValueError(f"Profile '{gui_settings['profile_name']}' not found by handler.")
            # args[ARG_PROFILE_CONFIG] = models.ProfileConfiguration(profile=profile_object) 
            # Placeholder structure:
            args[ARG_PROFILE_CONFIG] = {'profile': {'main': gui_settings["profile_name"]}}

            # 4. DiskLayoutConfiguration (Most Complex - Requires Deep Research)
            self.log("Setting Disk Config... (USER MUST VERIFY/IMPLEMENT)", "CRITICAL")
            # Research: archinstall.lib.disk.DiskLayoutConfiguration, .FilesystemHandler, .Partition, .Filesystem
            # This object needs to describe the target device and the desired layout (partitions, filesystems).
            target_device_path = gui_settings["target_disk_path"]
            # You might need to get a BlockDevice object first:
            # target_block_device = disk.BlockDevice(target_device_path) # Hypothetical

            if gui_settings["wipe_disk"]:
                # How does archinstall represent "wipe this device and apply a default layout"?
                # It might be a specific config_type or specific options passed to the constructor.
                # This placeholder is INSUFFICIENT. Needs real API call knowledge.
                args[ARG_DISK_CONFIG] = disk.DiskLayoutConfiguration(
                     config_type=disk.DiskLayoutType.Default, # VERIFY THIS ENUM/VALUE
                     device=target_device_path, # Pass Path object or BlockDevice object? Check constructor
                     wipe=True, # Ensure wipe flag is set
                     # May need to specify filesystem type for root (e.g., fs_type='ext4')
                     # May need to specify ESP size, swap size if 'Default' type requires it.
                )
            else:
                # How to represent "use pre-mounted/existing partitions"?
                args[ARG_DISK_CONFIG] = disk.DiskLayoutConfiguration(
                    config_type=disk.DiskLayoutType.Pre_mount # VERIFY THIS ENUM/VALUE
                    # Usually requires passing a dictionary mapping mountpoints ('/', '/boot/efi', '[SWAP]')
                    # to specific partition paths (/dev/sdaX) that the user selected/confirmed.
                    # mountpoints={ ... } # Requires significant GUI work to gather this mapping.
                )

            # 5. Optional Configurations (Set to None or create default objects)
            args[ARG_ENCRYPTION] = None # No encryption in this example
            # args[ARG_NETWORK_CONFIG] = models.NetworkConfiguration(nic='NetworkManager') # Example
            # args[ARG_AUDIO_CONFIG] = models.AudioConfiguration(audio='pipewire') # Example

            self.update_log_output("Successfully populated archinstall.arguments (Check TODOs!).", "INFO")
            # self.log(f"Arguments Prepared: {archinstall.arguments}", "DEBUG") # Very verbose debug
            return True # Success

        except ImportError as e:
             self.update_log_output(f"Import Error during argument preparation: {e}", "ERROR")
             self.update_log_output(traceback.format_exc(), "ERROR")
             QMessageBox.critical(self, "Library Error", f"Missing component from archinstall library needed for config: {e}")
             return False
        except Exception as e: 
            self.update_log_output(f"Error preparing archinstall arguments: {e}", "ERROR")
            self.update_log_output(traceback.format_exc(), "ERROR")
            QMessageBox.critical(self, "Configuration Error", f"Failed to prepare installation configuration objects: {e}\n\nCheck archinstall API/version and TODO comments.")
            return False


    def start_installation(self):
        """Gathers settings, populates archinstall.arguments, confirms, and starts thread."""
        if not ARCHINSTALL_LIBRARY_AVAILABLE:
             QMessageBox.critical(self, "Error", "Archinstall library not loaded. Cannot install.")
             return

        # Populate the global arguments dictionary using the dedicated method
        if not self.gather_settings_and_populate_args():
             self.update_log_output("Configuration gathering/population failed. Installation aborted.", "ERROR")
             return # Stop if config population failed

        # Confirmation Dialog - Retrieve data directly from archinstall.arguments for display accuracy
        try:
             # Safely get display values, using .get() or getattr with defaults
             # Getting target disk path directly from the argument dict is complex
             # Use the value from the combo box which was validated earlier
             target_disk_path_for_dialog = self.disk_combo.itemData(self.disk_combo.currentIndex()) or "N/A"
             
             # Try to get wipe status from the constructed disk config object
             disk_config_obj = archinstall.arguments.get(ARG_DISK_CONFIG)
             wipe_disk_val = getattr(disk_config_obj, 'wipe', False) if disk_config_obj else self.wipe_disk_checkbox.isChecked() # Fallback

             # Try to get profile name from constructed profile config object
             profile_config_obj = archinstall.arguments.get(ARG_PROFILE_CONFIG)
             profile_name_for_dialog = DEFAULT_DESKTOP_ENVIRONMENT_PROFILE # Default
             # Attempt to extract profile name if structure matches simple dict example
             if isinstance(profile_config_obj, dict):
                 profile_name_for_dialog = profile_config_obj.get('profile', {}).get('main', profile_name_for_dialog)
             # Add more specific checks here if using ProfileConfiguration object, e.g.
             # elif isinstance(profile_config_obj, models.ProfileConfiguration) and profile_config_obj.profile:
             #      profile_name_for_dialog = profile_config_obj.profile.name

        except Exception as e:
             self.update_log_output(f"Error retrieving arguments for confirmation dialog: {e}", "WARN")
             target_disk_path_for_dialog = "Error Retrieving"
             wipe_disk_val = False
             profile_name_for_dialog = "Error Retrieving"

        wipe_warning = "YES (ENTIRE DISK WILL BE ERASED!)" if wipe_disk_val else "NO (Advanced - Using existing partitions)"
        confirm_msg = (f"Ready to install Mai Bloom OS ({profile_name_for_dialog}) using the archinstall library:\n\n"
                       f"  - Target Disk: {target_disk_path_for_dialog}\n"
                       f"  - Wipe Disk & Auto-Configure: {wipe_warning}\n\n"
                       "Ensure all selections are correct.\nPROCEED WITH INSTALLATION?")
        
        reply = QMessageBox.question(self, 'Confirm Installation', confirm_msg, QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if reply == QMessageBox.No:
            self.update_log_output("Installation cancelled by user.")
            return

        # Start the installation thread
        self.install_button.setEnabled(False); self.scan_disks_button.setEnabled(False)
        self.log_output.clear(); self.update_log_output("Starting installation via archinstall library...")

        # Create thread (it will read the global archinstall.arguments)
        self.installer_thread = InstallerEngineThread() 
        self.installer_thread.installation_log.connect(self.update_log_output)
        self.installer_thread.installation_finished.connect(self.on_installation_finished)
        self.installer_thread.start() # Calls run() in a new thread

    def on_installation_finished(self, success, message):
        """Handles completion signal from the installer thread."""
        self.update_log_output(f"GUI: Installation finished signal. Success: {success}")
        if success:
            QMessageBox.information(self, "Installation Complete", message + "\nYou may now reboot.")
        else:
            log_content = self.log_output.toPlainText()
            last_log_lines = "\n".join(log_content.splitlines()[-20:]) # Show more log lines on error
            detailed_message = f"{message}\n\nLast log entries:\n---\n{last_log_lines}\n---"
            QMessageBox.critical(self, "Installation Failed", detailed_message)
            
        self.install_button.setEnabled(True); self.scan_disks_button.setEnabled(True)
        self.installer_thread = None 

        # Attempt unmount after completion/failure
        try:
            mount_point = archinstall.storage.get('MOUNT_POINT')
            if mount_point and Path(mount_point).is_mount(): # Check if it seems mounted
                 self.update_log_output("Attempting final unmount...")
                 unmount_process = subprocess.run(["umount", "-R", str(mount_point)], capture_output=True, text=True, check=False) # Use check=False
                 if unmount_process.returncode == 0:
                     self.update_log_output(f"Successfully unmounted {mount_point}.")
                 elif "not mounted" not in (unmount_process.stderr or "").lower():
                     self.update_log_output(f"Warning: Could not unmount {mount_point}: {unmount_process.stderr.strip()}", "WARN")
                 else:
                     self.update_log_output(f"{mount_point} was not mounted.", "DEBUG")
        except Exception as e:
             self.update_log_output(f"Error during final unmount attempt: {e}", "WARN")

    # select_post_install_script remains unchanged, currently unused by engine
    def select_post_install_script(self): pass
    # closeEvent remains unchanged
    def closeEvent(self, event): pass


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
    if not check_root():
        logging.error("Application must be run as root.")
        app_temp = QApplication.instance();
        if not app_temp: app_temp = QApplication(sys.argv)
        QMessageBox.critical(None, "Root Access Required", "This installer must be run with root privileges.")
        sys.exit(1)
    app = QApplication(sys.argv)
    installer_gui = MaiBloomInstallerApp()
    installer_gui.show()
    sys.exit(app.exec_())
