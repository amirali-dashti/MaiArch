##############################################################################
# Mai Bloom OS Installer - Based on Direct Archinstall Library Usage
# Approach derived from user-provided stable code snippet.
#
# IMPORTANT: User MUST research and correctly populate the
#            `archinstall.arguments` dictionary in gather_settings()
#            with objects/data structures matching their target
#            archinstall version's internal API expectations.
#            Placeholders and comments indicate where this is needed.
##############################################################################

import sys
import os
import traceback
import time
from pathlib import Path
from typing import Any, TYPE_CHECKING, Optional, Dict, List # Type hinting

# Set CWD to script directory if needed by archinstall relative paths? (Usually not necessary)
# script_path = Path(__file__).parent
# os.chdir(script_path)

from PyQt5.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout,
                             QLabel, QLineEdit, QPushButton, QComboBox,
                             QMessageBox, QFileDialog, QTextEdit, QCheckBox,
                             QGroupBox, QGridLayout, QSplitter)
from PyQt5.QtCore import QThread, pyqtSignal, Qt

# --- Attempt to import Archinstall components from User's Snippet ---
# User MUST ensure these imports work for their archinstall version
try:
    import archinstall
    from archinstall import info, debug, SysInfo # For logging/info from archinstall itself? Or replace with GUI log.
    from archinstall.lib import locale, disk    # DiskLayoutConfiguration, FilesystemHandler, LocaleConfiguration
    # from archinstall.lib.global_menu import GlobalMenu # <-- We are REPLACING this with GUI
    from archinstall.lib.configuration import ConfigurationOutput # Maybe useful for saving config?
    from archinstall.lib.installer import Installer # Core installer class
    from archinstall.lib.models import ProfileConfiguration, User, DiskEncryption, AudioConfiguration, Bootloader # Config models
    from archinstall.lib.models.network_configuration import NetworkConfiguration # Network config model
    from archinstall.lib.profile.profiles_handler import profile_handler # To handle profile logic?
    # Use constants from user's snippet - assuming they are correct for the target version
    ARG_DISK_CONFIG = 'disk_config'; ARG_LOCALE_CONFIG = 'locale_config'; ARG_ROOT_PASSWORD = '!root-password'
    ARG_USERS = '!users'; ARG_PROFILE_CONFIG = 'profile_config'; ARG_AUDIO_CONFIG = 'audio_config'
    ARG_KERNE = 'kernels'; ARG_NTP = 'ntp'; ARG_PACKAGES = 'packages'; ARG_BOOTLOADER = 'bootloader'
    ARG_MIRROR_CONFIG = 'mirror_config'; ARG_NETWORK_CONFIG = 'network_config'; ARG_TIMEZONE = 'timezone'
    ARG_SERVICES = 'services'; ARG_CUSTOM_COMMANDS = 'custom-commands'; ARG_ENCRYPTION = 'disk_encryption'
    ARG_SWAP = 'swap'; ARG_UKI = 'uki'; ARG_HOSTNAME = 'hostname' # Added hostname explicitly

    ARCHINSTALL_LIBRARY_AVAILABLE = True
    # Initialize the global arguments dictionary if archinstall expects it
    if not hasattr(archinstall, 'arguments'):
        archinstall.arguments = {}
    # Initialize storage if needed (based on user code using archinstall.storage)
    if not hasattr(archinstall, 'storage'):
        archinstall.storage = {}
    archinstall.storage['MOUNT_POINT'] = Path('/mnt/maibloom_install') # Use our dedicated mount point

    # Redirect archinstall's info/debug? Or let them print to console?
    # For now, let them print, but GUI log should be primary.

except ImportError as e:
    print(f"CRITICAL ERROR: Failed to import required archinstall modules: {e}", file=sys.stderr)
    print("This installer cannot function without a working archinstall library environment.", file=sys.stderr)
    print("Please ensure archinstall is installed correctly and accessible via Python.", file=sys.stderr)
    ARCHINSTALL_LIBRARY_AVAILABLE = False
    # Define dummy exception for GUI to load
    class ArchinstallError(Exception): pass


# --- App Configuration ---
APP_CATEGORIES = { # Keep user's categories
    "Daily Use": ["firefox", "vlc", "gwenview", "okular", "libreoffice-still", "ark", "kate"],
    "Programming": ["git", "code", "python", "gcc", "gdb", "base-devel"],
    "Gaming": ["steam", "lutris", "wine", "noto-fonts-cjk"],
    "Education": ["gcompris-qt", "kgeography", "stellarium", "kalgebra"]
}
DEFAULT_DESKTOP_ENVIRONMENT_PROFILE = "kde" # For Mai Bloom OS
MOUNT_POINT = archinstall.storage['MOUNT_POINT'] if ARCHINSTALL_LIBRARY_AVAILABLE else Path('/mnt/maibloom_install_fallback')

def check_root(): return os.geteuid() == 0


# --- Installer Engine Thread (Based on User's Snippet Logic) ---
class InstallerEngineThread(QThread):
    installation_finished = pyqtSignal(bool, str)
    installation_log = pyqtSignal(str)
    # disk_scan_complete not needed if disk module used directly in GUI? Or keep for consistency?
    # Let's assume GUI handles scan for now using the library directly if possible.

    def __init__(self, pre_populated_arguments: Dict):
        super().__init__()
        # We assume archinstall.arguments is populated by the GUI before starting
        # self.args_snapshot = pre_populated_arguments # Keep a copy if needed?
        self._running = True

    def log(self, message, level="INFO"):
        """Sends a log message to the GUI."""
        self.installation_log.emit(f"[{level}] {message}")
        QApplication.processEvents()

    def stop(self):
        """Requests the installation process to stop."""
        self.log("Stop request received. Installation will halt before next major step.", "WARN")
        self._running = False
        # Note: Doesn't forcefully kill ongoing operations like pacstrap.

    # perform_installation logic adapted from user's snippet
    def perform_installation(self, mountpoint: Path) -> None:
        """Performs the installation steps using archinstall library calls."""
        self.log('Starting installation steps using Archinstall library...')
        
        # Retrieve config objects/values from the global arguments dict
        # Need robust error handling if keys are missing (GUI should ensure they are set)
        try:
            disk_config: disk.DiskLayoutConfiguration = archinstall.arguments[ARG_DISK_CONFIG]
            locale_config: locale.LocaleConfiguration = archinstall.arguments[ARG_LOCALE_CONFIG]
            disk_encryption: Optional[disk.DiskEncryption] = archinstall.arguments.get(ARG_ENCRYPTION, None)
            hostname: str = archinstall.arguments.get(ARG_HOSTNAME, 'maibloom-os')
            users: List[User] = archinstall.arguments.get(ARG_USERS, [])
            root_pw: Optional[str] = archinstall.arguments.get(ARG_ROOT_PASSWORD, None)
            profile_config: Optional[ProfileConfiguration] = archinstall.arguments.get(ARG_PROFILE_CONFIG, None)
            additional_packages: List[str] = archinstall.arguments.get(ARG_PACKAGES, [])
            bootloader_choice: Bootloader = archinstall.arguments.get(ARG_BOOTLOADER, Bootloader.SystemdBoot if SysInfo.has_uefi() else Bootloader.Grub) # Sensible default
            kernels: List[str] = archinstall.arguments.get(ARG_KERNE, ['linux'])
            timezone: Optional[str] = archinstall.arguments.get(ARG_TIMEZONE, None)
            enable_ntp: bool = archinstall.arguments.get(ARG_NTP, True) # Default NTP to True
            enable_swap: bool = archinstall.arguments.get(ARG_SWAP, True) # Default Swap to True
            audio_config: Optional[AudioConfiguration] = archinstall.arguments.get(ARG_AUDIO_CONFIG, None) # Could default this
            network_config: Optional[NetworkConfiguration] = archinstall.arguments.get(ARG_NETWORK_CONFIG, None) # Could default this

            # Hardcode some settings if not configured by GUI, e.g., audio/network defaults
            # Example: If audio_config is None, create a default Pipewire config
            if audio_config is None:
                self.log("Audio config not set, defaulting using AudioConfiguration.", "DEBUG")
                # You need to check how AudioConfiguration is instantiated
                # audio_config = AudioConfiguration(audio='pipewire') # Hypothetical
                # archinstall.arguments[ARG_AUDIO_CONFIG] = audio_config # Store it back?
                pass # For now, do nothing, rely on profile or manual post-install

            # Example: If network_config is None, create a default NetworkManager config
            if network_config is None:
                 self.log("Network config not set, defaulting using NetworkConfiguration.", "DEBUG")
                 # network_config = NetworkConfiguration(nic='NetworkManager') # Hypothetical
                 # archinstall.arguments[ARG_NETWORK_CONFIG] = network_config # Store it back?
                 pass # For now, rely on profile or manual post-install

        except KeyError as e:
            self.log(f"Configuration key missing in archinstall.arguments: {e}", "ERROR")
            raise ArchinstallError(f"Missing required configuration: {e}") from e
            
        # Determine if repo flags are needed (GUI could set these)
        enable_testing = 'testing' in archinstall.arguments.get('additional-repositories', [])
        enable_multilib = 'multilib' in archinstall.arguments.get('additional-repositories', [])
        run_mkinitcpio = not archinstall.arguments.get(ARG_UKI, False) # UKI usage

        # --- Main Installation using Installer context manager ---
        self.log(f"Initializing Installer for mountpoint {mountpoint}...")
        # Kernels argument is required by Installer
        with Installer(mountpoint, disk_config, disk_encryption=disk_encryption, kernels=kernels) as installation:
            # Note: The Installer context manager might handle mounting/unmounting
            
            # Mount filesystem if not pre-mounted (based on user snippet)
            # GUI needs to configure disk_config correctly for 'Pre_mount' or other types
            if disk_config.config_type != disk.DiskLayoutType.Pre_mount:
                 self.log("Mounting configured layout...")
                 installation.mount_ordered_layout() # Requires DiskLayoutConfiguration to be properly set up

            if not self._running: raise InterruptedError("Installation stopped.")

            self.log("Performing sanity checks...")
            installation.sanity_check()

            if disk_encryption and disk_encryption.encryption_type != disk.EncryptionType.NoEncryption:
                self.log("Handling disk encryption setup...")
                installation.generate_key_files() # Needs correctly configured DiskEncryption object

            # Mirror configuration (GUI could add a step for this)
            if mirror_config := archinstall.arguments.get(ARG_MIRROR_CONFIG, None):
                 self.log("Setting mirrors on host...")
                 installation.set_mirrors(mirror_config, on_target=False)

            if not self._running: raise InterruptedError("Installation stopped.")

            # Minimal Installation (Base system + essential config)
            self.log("Performing minimal installation (pacstrap base, locale, hostname)...")
            installation.minimal_installation(
                testing=enable_testing,
                multilib=enable_multilib,
                mkinitcpio=run_mkinitcpio,
                hostname=hostname,
                locale_config=locale_config # Requires LocaleConfiguration object
            )
            self.log("Minimal installation complete.")

            if not self._running: raise InterruptedError("Installation stopped.")

            # Set mirrors on target system
            if mirror_config:
                self.log("Setting mirrors on target system...")
                installation.set_mirrors(mirror_config, on_target=True)

            # Swap setup (if enabled)
            if enable_swap:
                self.log("Setting up swap (zram)...")
                # User code specified 'zram', make sure this is intended or configurable
                installation.setup_swap('zram') 

            # Bootloader needs special handling based on choice and mode
            self.log(f"Adding bootloader: {bootloader_choice.value}")
            # The user code had a specific check for GRUB + UEFI, let's include it
            if bootloader_choice == Bootloader.Grub and SysInfo.has_uefi():
                self.log("Ensuring GRUB package is installed for UEFI setup...")
                installation.add_additional_packages("grub") # Installs grub package if not present

            installation.add_bootloader(bootloader_choice, archinstall.arguments.get(ARG_UKI, False))
            self.log("Bootloader setup step complete.")

            if not self._running: raise InterruptedError("Installation stopped.")

            # Network Configuration
            if network_config:
                self.log("Configuring network...")
                # The user code had profile_config here, check if it's needed by install_network_config
                network_config.install_network_config(installation, profile_config)
            else:
                self.log("Skipping network configuration (no config provided). Relies on NetworkManager package being installed.", "WARN")

            # User Creation
            if users:
                self.log(f"Creating users: {[user.user_name for user in users]}")
                installation.create_users(users) # Requires list of User objects
            else:
                 self.log("No users specified to create.", "WARN")

            if not self._running: raise InterruptedError("Installation stopped.")

            # Audio Configuration
            if audio_config:
                self.log(f"Configuring audio: {audio_config.audio}") # Assuming audio attr exists
                audio_config.install_audio_config(installation)
            else:
                self.log("Skipping audio configuration (no config provided).", "INFO")

            # Install Additional Packages (from APP_CATEGORIES etc)
            if additional_packages:
                self.log(f"Installing {len(additional_packages)} additional packages...")
                installation.add_additional_packages(additional_packages)
                self.log("Additional packages installed.")

            # Install Profile (e.g., KDE)
            # This is where the DE gets installed if profile_config is correctly set
            if profile_config:
                self.log(f"Installing profile: {profile_config.profile.name if profile_config.profile else 'N/A'}")
                # This function likely handles installing profile packages and running setup scripts
                profile_handler.install_profile_config(installation, profile_config)
                self.log("Profile installation step complete.")
            else:
                 self.log("No profile configuration provided.", "WARN")


            if not self._running: raise InterruptedError("Installation stopped.")

            # Timezone
            if timezone:
                self.log(f"Setting timezone: {timezone}")
                installation.set_timezone(timezone)

            # NTP
            if enable_ntp:
                self.log("Enabling NTP time synchronization...")
                installation.activate_time_synchronization()

            # Accessibility (example from user code)
            # if archinstall.accessibility_tools_in_use():
            #     installation.enable_espeakup()

            # Root Password
            if root_pw:
                self.log("Setting root password...")
                installation.user_set_pw('root', root_pw)
                self.log("Root password set.")
            else:
                 self.log("No root password provided!", "WARN")


            # Profile Post-Install hooks
            if profile_config and hasattr(profile_config, 'profile') and profile_config.profile:
                 self.log(f"Running post-install hooks for profile {profile_config.profile.name}...")
                 profile_config.profile.post_install(installation)

            # Enable Additional Services (GUI could configure this)
            if services := archinstall.arguments.get(ARG_SERVICES, None):
                self.log(f"Enabling services: {services}")
                installation.enable_service(services)

            # Custom Commands (GUI could configure this)
            if custom_commands := archinstall.arguments.get(ARG_CUSTOM_COMMANDS, None):
                self.log("Running custom commands...")
                archinstall.run_custom_user_commands(custom_commands, installation)

            if not self._running: raise InterruptedError("Installation stopped.")

            # Final Steps
            self.log("Generating fstab...")
            installation.genfstab()
            self.log("fstab generated.")

            self.log("Installation steps successfully completed via Archinstall library!")
            self.installation_finished.emit(True, f"Mai Bloom OS ({DEFAULT_DESKTOP_ENVIRONMENT_NAME}) installed successfully using archinstall library!")

    def run(self):
        """Main thread execution logic."""
        mount_point = archinstall.storage['MOUNT_POINT'] # Get mount point

        try:
            if not ARCHINSTALL_LIBRARY_AVAILABLE:
                 raise ArchinstallError("Archinstall library components failed to import.")

            self.log("Starting installation process...")

            # --- Filesystem Operations ---
            self.log("Initializing Filesystem Handler...")
            # Requires ARG_DISK_CONFIG and ARG_ENCRYPTION to be set in archinstall.arguments
            fs_handler = disk.FilesystemHandler(
                archinstall.arguments[ARG_DISK_CONFIG],
                archinstall.arguments.get(ARG_ENCRYPTION, None)
            )
            self.log("Performing filesystem operations (formatting)...")
            fs_handler.perform_filesystem_operations()
            self.log("Filesystem operations complete.")

            if not self._running: raise InterruptedError("Installation stopped after formatting.")

            # --- Perform Installation ---
            self.perform_installation(mount_point) # Calls the main logic adapted from user code

        # --- Error Handling ---
        except InterruptedError as e:
            self.log(f"Installation process was interrupted: {e}", "WARN")
            self.installation_finished.emit(False, f"Installation interrupted: {e}")
        except ArchinstallError as e: # Catch specific archinstall errors if defined
            self.log(f"Archinstall Error: {e}", "ERROR")
            self.log(traceback.format_exc(), "ERROR")
            self.installation_finished.emit(False, f"Installation failed: {e}")
        except KeyError as e: # Catch missing keys in archinstall.arguments
            self.log(f"Configuration key missing: {e}", "ERROR")
            self.log(traceback.format_exc(), "ERROR")
            self.installation_finished.emit(False, f"Configuration Error: Missing key '{e}'")
        except Exception as e: # General catch-all
            self.log(f"An unexpected critical error occurred: {type(e).__name__}: {e}", "CRITICAL_ERROR")
            self.log(traceback.format_exc(), "CRITICAL_ERROR")
            self.installation_finished.emit(False, f"A critical error occurred: {e}")
        finally:
            # Unmounting should happen after thread signals completion/failure
            self.log("InstallerEngineThread finished execution.", "INFO")
            # Maybe emit a signal here to trigger unmount in the main thread?

# --- Main Application Window ---
class MaiBloomInstallerApp(QWidget):
    def __init__(self):
        super().__init__()
        self.installation_settings_for_gui = {} # Store GUI choices before conversion
        self.installer_thread = None
        self.init_ui()
        self.update_log_output("Welcome to Mai Bloom OS Installer!")
        if not ARCHINSTALL_LIBRARY_AVAILABLE:
             self.update_log_output("CRITICAL ERROR: Archinstall library not loaded. Installation impossible.", "ERROR")
             QMessageBox.critical(self, "Startup Error", "Failed to load essential Archinstall library components.\nPlease ensure Archinstall is correctly installed and accessible via Python.\nThe application cannot continue.")
             # Consider exiting or disabling install button permanently
             self.install_button.setEnabled(False)
             self.scan_disks_button.setEnabled(False)
        else:
             self.update_log_output("Archinstall library loaded successfully.")
             self.trigger_disk_scan() # Trigger initial scan

    def init_ui(self):
        self.setWindowTitle(f'Mai Bloom OS Installer ({DEFAULT_DESKTOP_ENVIRONMENT_PROFILE} via Archinstall Lib)')
        self.setGeometry(100, 100, 850, 700)
        overall_layout = QVBoxLayout(self)

        title_label = QLabel(f"<b>Install Mai Bloom OS ({DEFAULT_DESKTOP_ENVIRONMENT_PROFILE})</b>")
        title_label.setAlignment(Qt.AlignCenter)
        overall_layout.addWidget(title_label)
        overall_layout.addWidget(QLabel("<small>This installer uses the <b>archinstall</b> library directly.</small>"))
        
        splitter = QSplitter(Qt.Horizontal); overall_layout.addWidget(splitter)
        controls_widget = QWidget(); controls_layout = QVBoxLayout(controls_widget)

        # --- GUI Controls ---
        # Disk Setup
        disk_group = QGroupBox("1. Disk Setup"); disk_layout_vbox = QVBoxLayout()
        self.scan_disks_button = QPushButton("Scan for Disks"); self.scan_disks_button.clicked.connect(self.trigger_disk_scan)
        disk_layout_vbox.addWidget(self.scan_disks_button)
        self.disk_combo = QComboBox(); self.disk_combo.setToolTip("Select target disk. Data will be erased if 'Wipe Disk' is checked.")
        disk_layout_vbox.addLayout(self.create_form_row("Target Disk:", self.disk_combo))
        self.wipe_disk_checkbox = QCheckBox("Wipe disk & auto-configure standard layout"); self.wipe_disk_checkbox.setChecked(True)
        self.wipe_disk_checkbox.setToolTip("Let archinstall erase and partition the disk automatically (Requires research into DiskLayoutConfiguration).")
        disk_layout_vbox.addWidget(self.wipe_disk_checkbox)
        disk_group.setLayout(disk_layout_vbox); controls_layout.addWidget(disk_group)

        # System & User Config
        system_group = QGroupBox("2. System & User"); system_layout_grid = QGridLayout()
        self.hostname_input = QLineEdit("maibloom-os"); system_layout_grid.addWidget(QLabel("Hostname:"), 0, 0); system_layout_grid.addWidget(self.hostname_input, 0, 1)
        self.username_input = QLineEdit("maiuser"); system_layout_grid.addWidget(QLabel("Username:"), 1, 0); system_layout_grid.addWidget(self.username_input, 1, 1)
        self.password_input = QLineEdit(); self.password_input.setPlaceholderText("User & Root Password"); self.password_input.setEchoMode(QLineEdit.Password)
        system_layout_grid.addWidget(QLabel("Password (User+Root):"), 2, 0); system_layout_grid.addWidget(self.password_input, 2, 1)
        self.locale_input = QLineEdit("en_US.UTF-8"); system_layout_grid.addWidget(QLabel("Locale:"), 3,0); system_layout_grid.addWidget(self.locale_input, 3,1)
        self.kb_layout_input = QLineEdit("us"); system_layout_grid.addWidget(QLabel("Keyboard Layout:"), 4,0); system_layout_grid.addWidget(self.kb_layout_input, 4,1)
        self.timezone_input = QLineEdit("UTC"); system_layout_grid.addWidget(QLabel("Timezone:"), 5,0); system_layout_grid.addWidget(self.timezone_input, 5,1)
        system_group.setLayout(system_layout_grid); controls_layout.addWidget(system_group)
        
        # Additional Apps
        app_group = QGroupBox(f"3. Additional Apps (on top of {DEFAULT_DESKTOP_ENVIRONMENT_PROFILE})"); app_layout_grid = QGridLayout()
        self.app_category_checkboxes = {}
        row, col = 0,0
        for cat_name in APP_CATEGORIES.keys():
            self.app_category_checkboxes[cat_name] = QCheckBox(f"{cat_name}"); self.app_category_checkboxes[cat_name].setToolTip(f"Install: {', '.join(APP_CATEGORIES[cat_name][:3])}...")
            app_layout_grid.addWidget(self.app_category_checkboxes[cat_name], row, col); col +=1
            if col > 1: col = 0; row +=1
        app_group.setLayout(app_layout_grid); controls_layout.addWidget(app_group)
        
        controls_layout.addStretch(1); splitter.addWidget(controls_widget)

        # Log Output Area
        log_group_box = QGroupBox("Installation Log"); log_layout_vbox = QVBoxLayout()
        self.log_output = QTextEdit(); self.log_output.setReadOnly(True); self.log_output.setLineWrapMode(QTextEdit.NoWrap); self.log_output.setStyleSheet("font-family: monospace;")
        log_layout_vbox.addWidget(self.log_output); log_group_box.setLayout(log_layout_vbox); splitter.addWidget(log_group_box)
        splitter.setSizes([400, 450])
        
        # Install Button
        self.install_button = QPushButton(f"Install Mai Bloom OS ({DEFAULT_DESKTOP_ENVIRONMENT_PROFILE})")
        self.install_button.setStyleSheet("background-color: lightblue; padding: 10px; font-weight: bold;"); self.install_button.setToolTip("Begin installation using archinstall library.")
        self.install_button.clicked.connect(self.start_installation)
        button_layout = QHBoxLayout(); button_layout.addStretch(); button_layout.addWidget(self.install_button); button_layout.addStretch(); overall_layout.addLayout(button_layout)

    def create_form_row(self, label_text, widget):
        row_layout = QHBoxLayout(); label = QLabel(label_text); label.setFixedWidth(120)
        row_layout.addWidget(label); row_layout.addWidget(widget); return row_layout

    def trigger_disk_scan(self):
        """Initiates disk scan using archinstall library (requires user implementation)."""
        if not ARCHINSTALL_LIBRARY_AVAILABLE:
            self.update_log_output("Disk Scan unavailable: Archinstall library not loaded.", "ERROR"); return
            
        self.update_log_output("GUI: Requesting disk scan via archinstall library...")
        self.scan_disks_button.setEnabled(False)
        try:
            # --- USER ACTION REQUIRED ---
            # Replace this with direct call to your archinstall disk listing function
            # This needs to be synchronous or handled with another thread if slow.
            # Example using a hypothetical function found during research:
            # all_devices = archinstall.lib.disk.all_blockdevices() # Or whatever the function is
            
            # Using the placeholder logic structure from InstallerEngineThread for GUI context
            processed_disks = {}
            self.update_log_output(" (Using placeholder disk scan logic - USER MUST REPLACE)", "WARN")
            # You'd call the *actual* archinstall function here. For demo, mimic the placeholder:
            if disk_module_actual: # Use the potentially mocked or real module
                 block_devices = disk_module_actual.get_all_blockdevices() 
                 # --- Filtering logic copied from InstallerEngineThread.run_disk_scan ---
                 # --- This filtering should ideally happen here in the GUI thread ---
                 # --- based on the objects returned by the real archinstall function ---
                 self.log(f"Found {len(block_devices)} block devices. Filtering...", "DEBUG")
                 for device in block_devices:
                     dev_path_str = str(getattr(device,'path', 'N/A'))
                     dev_type = str(getattr(device, 'type', 'unknown')).lower()
                     dev_ro = getattr(device, 'read_only', True)
                     dev_pkname = getattr(device, 'pkname', None)
                     dev_model = getattr(device, 'model', 'Unknown Model')
                     dev_size_bytes = int(getattr(device, 'size', 0))

                     if dev_type == 'disk' and not dev_ro and not dev_pkname and dev_size_bytes >= 20 * (1024**3):
                         # Simplified root check for GUI context
                          processed_disks[dev_path_str] = {
                              "model": dev_model,
                              "size": f"{dev_size_bytes / (1024**3):.2f} GB",
                              "path": dev_path_str
                          }
            # --- End Placeholder/Filtering Logic ---

            self.on_disk_scan_complete(processed_disks) # Update GUI with results

        except Exception as e:
            self.update_log_output(f"Disk Scan Error: {e}", "ERROR")
            self.update_log_output(traceback.format_exc(), "ERROR")
            self.on_disk_scan_complete({}) # Send empty results
            QMessageBox.critical(self, "Disk Scan Error", f"Failed to scan disks using archinstall library: {e}")
        finally:
            self.scan_disks_button.setEnabled(True)


    def on_disk_scan_complete(self, disks_data):
        """Updates the disk combo box with scanned disks."""
        self.update_log_output(f"GUI: Disk scan complete. Populating {len(disks_data)} disk(s).")
        self.disk_combo.clear()
        if disks_data:
            for path_key, info_dict in sorted(disks_data.items()):
                display_text = f"{path_key} - {info_dict.get('model', 'N/A')} ({info_dict.get('size', 'N/A')})"
                self.disk_combo.addItem(display_text, userData=path_key)
        else:
            self.update_log_output("GUI: No suitable disks found by scan.", "WARN")

    def update_log_output(self, message, level="INFO"):
        """Appends a message to the log view."""
        prefix = f"[{level}] " if level != "INFO" else ""
        self.log_output.append(prefix + message)
        self.log_output.ensureCursorVisible()
        if level not in ["DEBUG", "CMD_OUT", "CMD_ERR"]: # Avoid excessive spinning on debug/cmd logs
             QApplication.processEvents()

    def gather_settings_and_populate_args(self) -> bool:
        """
        Gathers settings from GUI and populates archinstall.arguments.
        Returns True if successful, False otherwise.
        THIS IS THE MOST CRITICAL PART FOR THE USER TO IMPLEMENT CORRECTLY.
        """
        self.update_log_output("Gathering settings and preparing archinstall arguments...")
        gui_settings = {}
        
        # --- Disk ---
        selected_disk_index = self.disk_combo.currentIndex()
        if selected_disk_index < 0:
            QMessageBox.warning(self, "Input Error", "Please select a target disk."); return False
        target_disk_path = self.disk_combo.itemData(selected_disk_index)
        if not target_disk_path:
            QMessageBox.warning(self, "Input Error", "Invalid disk selected."); return False
        gui_settings["target_disk_path"] = target_disk_path
        gui_settings["wipe_disk"] = self.wipe_disk_checkbox.isChecked()

        # --- System & User ---
        gui_settings["hostname"] = self.hostname_input.text().strip()
        gui_settings["username"] = self.username_input.text().strip()
        gui_settings["password"] = self.password_input.text() # User & Root password
        gui_settings["locale"] = self.locale_input.text().strip()
        gui_settings["kb_layout"] = self.kb_layout_input.text().strip()
        gui_settings["timezone"] = self.timezone_input.text().strip()
        
        # --- Validation ---
        if not all([gui_settings["hostname"], gui_settings["username"], gui_settings["password"],
                    gui_settings["locale"], gui_settings["kb_layout"], gui_settings["timezone"]]):
            QMessageBox.warning(self, "Input Error", "Please fill all System & User fields."); return False

        # --- Profile & Packages ---
        gui_settings["profile"] = DEFAULT_DESKTOP_ENVIRONMENT_PROFILE # Hardcoded KDE
        additional_packages = []
        for cat_name, checkbox_widget in self.app_category_checkboxes.items():
            if checkbox_widget.isChecked():
                additional_packages.extend(APP_CATEGORIES.get(cat_name, []))
        # Add essentials mentioned in user's snippet/common sense
        base_essentials = ["sudo", "nano"] 
        additional_packages = list(set(additional_packages + base_essentials))
        gui_settings["additional_packages"] = additional_packages

        # --- Populate archinstall.arguments ---
        # !!! USER ACTION REQUIRED: Replace placeholders with actual object instantiation !!!
        try:
            global args # Modify global arguments dictionary
            args = archinstall.arguments # Get reference

            args[ARG_HOSTNAME] = gui_settings["hostname"]
            args[ARG_ROOT_PASSWORD] = gui_settings["password"]
            args[ARG_TIMEZONE] = gui_settings["timezone"]
            args[ARG_KERNE] = ['linux'] # Default kernel
            args[ARG_NTP] = True
            args[ARG_SWAP] = True # Let installer handle swap based on defaults/profile

            # Locale Configuration Object
            # TODO: Research how to create LocaleConfiguration. Takes lang + kb_layout?
            # args[ARG_LOCALE_CONFIG] = locale.LocaleConfiguration(kb_layout=gui_settings["kb_layout"], sys_lang=gui_settings["locale"], sys_enc='UTF-8') # Hypothetical
            args[ARG_LOCALE_CONFIG] = {"kb_layout": gui_settings["kb_layout"], "sys_lang": gui_settings["locale"].split('.')[0], "sys_enc": "UTF-8"} # Simple Dict fallback? Check archinstall source.
            self.log(f"Set locale config (check type): {args[ARG_LOCALE_CONFIG]}", "DEBUG")

            # User Configuration Object(s)
            # TODO: Research how User objects are created and structure for ARG_USERS (list?)
            # args[ARG_USERS] = [User(gui_settings["username"], gui_settings["password"], sudo=True)] # Hypothetical
            args[ARG_USERS] = [{"username": gui_settings["username"], "password": gui_settings["password"], "sudo": True}] # Simple Dict fallback? Check source.
            self.log(f"Set user config (check type): {args[ARG_USERS]}", "DEBUG")

            # Profile Configuration Object
            # TODO: Research ProfileConfiguration structure for KDE
            # args[ARG_PROFILE_CONFIG] = ProfileConfiguration(profile=profile_handler.get_profile(gui_settings["profile"])) # Hypothetical
            # May need to specify audio (pipewire?), greeter (sddm?) if profile doesn't default
            args[ARG_PROFILE_CONFIG] = {"profile": {"main": gui_settings["profile"]}} # Simple Dict fallback based on common JSON structure? Check source.
            self.log(f"Set profile config (check type): {args[ARG_PROFILE_CONFIG]}", "DEBUG")

            # Additional Packages (already prepared list)
            args[ARG_PACKAGES] = gui_settings["additional_packages"]
            self.log(f"Set additional packages: {args[ARG_PACKAGES]}", "DEBUG")

            # Bootloader (determine based on EFI)
            is_efi = os.path.exists("/sys/firmware/efi")
            args[ARG_BOOTLOADER] = Bootloader.SystemdBoot if is_efi else Bootloader.Grub # Use Bootloader enum if available
            self.log(f"Set bootloader: {args[ARG_BOOTLOADER]}", "DEBUG")

            # Disk Configuration Object (VERY COMPLEX - Requires most research)
            # TODO: Research DiskLayoutConfiguration and FilesystemHandler.
            # How to represent "wipe disk X and auto-partition with standard layout"?
            # This likely involves creating Partition objects and Filesystem objects.
            # Placeholder - This will almost certainly FAIL without correct object structure.
            if gui_settings["wipe_disk"]:
                 # This needs to represent the *intent* for FilesystemHandler and Installer
                 # It might involve creating a specific layout object.
                 # This placeholder is insufficient. Research archinstall disk handling.
                args[ARG_DISK_CONFIG] = {
                     'config_type': disk.DiskLayoutType.Default, # Hypothetical Enum value for auto
                     'device_path': Path(gui_settings["target_disk_path"]),
                     'wipe': True,
                     # Need details for FS types, sizes (ESP, Swap, Root) if "Default" type requires them
                     'layout': { # Very hypothetical structure
                          '/': {'fs': 'ext4', 'options': 'defaults', 'size': '100%'},
                          # Swap and ESP might be handled implicitly by Default type or need definition
                     }
                 }
                 # It's more likely you need to instantiate disk.DiskLayoutConfiguration
                 # with specific parameters or partitions after finding the BlockDevice.
                 # disk_layout = disk.DiskLayoutConfiguration(...)
                 # args[ARG_DISK_CONFIG] = disk_layout
                 self.log("Set disk config (Wipe/Auto) - PLACEHOLDER NEEDS REAL IMPLEMENTATION", "WARN")
            else:
                 # How to represent using existing partitions? Research needed.
                 # args[ARG_DISK_CONFIG] = disk.DiskLayoutConfiguration(config_type=disk.DiskLayoutType.Pre_mount, ...) # Hypothetical
                 args[ARG_DISK_CONFIG] = {'config_type': disk.DiskLayoutType.Pre_mount} # Even more basic placeholder
                 self.log("Set disk config (Use Existing) - PLACEHOLDER NEEDS REAL IMPLEMENTATION", "WARN")


            # Other optional configs (Encryption, Network, Audio) - set to None or default objects
            args[ARG_ENCRYPTION] = None # Example: No encryption
            # args[ARG_NETWORK_CONFIG] = NetworkConfiguration(nic='NetworkManager') # Example default
            # args[ARG_AUDIO_CONFIG] = AudioConfiguration(audio='pipewire') # Example default

            self.update_log_output("Successfully populated archinstall.arguments.", "INFO")
            # print(f"DEBUG: archinstall.arguments = {archinstall.arguments}") # For debugging
            return True

        except AttributeError as e:
             self.update_log_output(f"Error accessing archinstall component: {e}. Library structure mismatch?", "ERROR")
             self.update_log_output(traceback.format_exc(), "ERROR")
             QMessageBox.critical(self, "Library Error", f"Could not prepare configuration using archinstall library components.\nError: {e}\n\nCheck library version and structure.")
             return False
        except Exception as e:
            self.update_log_output(f"Error preparing archinstall arguments: {e}", "ERROR")
            self.update_log_output(traceback.format_exc(), "ERROR")
            QMessageBox.critical(self, "Configuration Error", f"Failed to prepare installation configuration: {e}")
            return False


    def start_installation(self):
        """Gathers settings, populates archinstall.arguments, and starts the thread."""
        if not ARCHINSTALL_LIBRARY_AVAILABLE:
             QMessageBox.critical(self, "Error", "Archinstall library not loaded. Cannot install.")
             return

        # Populate the global arguments dictionary
        if not self.gather_settings_and_populate_args():
             self.update_log_output("Configuration gathering failed. Installation aborted.", "ERROR")
             return # Stop if config population failed

        # Confirmation Dialog
        target_disk = archinstall.arguments.get(ARG_DISK_CONFIG, {}).get('device_path', 'N/A')
        wipe_disk = archinstall.arguments.get(ARG_DISK_CONFIG, {}).get('wipe', False)
        profile_name = archinstall.arguments.get(ARG_PROFILE_CONFIG, {}).get('profile', {}).get('main', 'N/A')

        wipe_warning = "YES (ENTIRE DISK WILL BE ERASED!)" if wipe_disk else "NO (Advanced - Using existing partitions)"
        confirm_msg = (f"Ready to install Mai Bloom OS ({profile_name}) using the archinstall library:\n\n"
                       f"  - Target Disk: {target_disk}\n"
                       f"  - Wipe Disk & Auto-Configure: {wipe_warning}\n\n"
                       "PROCEED WITH INSTALLATION?")
        
        reply = QMessageBox.question(self, 'Confirm Installation', confirm_msg, QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if reply == QMessageBox.No:
            self.update_log_output("Installation cancelled by user.")
            return

        # Start the installation thread
        self.install_button.setEnabled(False); self.scan_disks_button.setEnabled(False)
        self.log_output.clear(); self.update_log_output("Starting installation via archinstall library...")

        self.installer_thread = InstallerEngineThread(archinstall.arguments) # Pass populated dict if needed, though thread reads global directly now
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
            last_log_lines = "\n".join(log_content.splitlines()[-15:])
            detailed_message = f"{message}\n\nLast log entries:\n---\n{last_log_lines}\n---"
            QMessageBox.critical(self, "Installation Failed", detailed_message)
            
        self.install_button.setEnabled(True); self.scan_disks_button.setEnabled(True)
        self.installer_thread = None 

        # Attempt unmount after completion
        mount_point = archinstall.storage.get('MOUNT_POINT')
        if mount_point:
             self.update_log_output("Attempting final unmount...")
             # Use subprocess directly as engine thread is finished
             unmount_process = subprocess.run(["umount", "-R", str(mount_point)], capture_output=True, text=True)
             if unmount_process.returncode == 0:
                 self.update_log_output(f"Successfully unmounted {mount_point}.")
             else:
                 # Check stderr, ignore "not mounted" errors potentially
                 if "not mounted" not in unmount_process.stderr.lower():
                     self.update_log_output(f"Could not unmount {mount_point}: {unmount_process.stderr.strip()}", "WARN")
                 else:
                     self.update_log_output(f"{mount_point} was not mounted.", "DEBUG")


    def select_post_install_script(self): # Keep this for potential future use
        """Allows user to select an optional script."""
        # ... (same as before) ...
        pass


    def closeEvent(self, event): # Keep close event handler
        # ... (same as before) ...
        pass


if __name__ == '__main__':
    # Basic console logging setup
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    if not check_root():
        logging.error("Application must be run as root.")
        app_temp = QApplication.instance();
        if not app_temp: app_temp = QApplication(sys.argv)
        QMessageBox.critical(None, "Root Access Required", "This installer must be run with root privileges.")
        sys.exit(1)
        
    app = QApplication(sys.argv)
    installer = MaiBloomInstallerApp()
    installer.show()
    sys.exit(app.exec_())

