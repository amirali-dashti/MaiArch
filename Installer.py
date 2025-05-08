# --- Required Imports (Ensure these are present in your full script) ---
import sys
import os
import traceback
import time
import logging
from pathlib import Path
from typing import Any, TYPE_CHECKING, Optional, Dict, List # Type hinting

from PyQt5.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout,
                             QLabel, QLineEdit, QPushButton, QComboBox,
                             QMessageBox, QFileDialog, QTextEdit, QCheckBox,
                             QGroupBox, QGridLayout, QSplitter)
from PyQt5.QtCore import QThread, pyqtSignal, Qt # QThread/pyqtSignal needed for interaction with backend

# --- Placeholder: Assume InstallerEngineThread Class exists ---
# In your full script, the InstallerEngineThread class definition 
# (from the previous response, wrapping your archinstall library logic) 
# should be present here or imported.
class InstallerEngineThread(QThread): 
    # Dummy thread class for GUI structure demonstration if backend is in separate file
    installation_finished = pyqtSignal(bool, str)
    installation_log = pyqtSignal(str)
    disk_scan_complete = pyqtSignal(dict)
    def __init__(self, installation_settings): super().__init__(); self.settings=installation_settings
    def run_disk_scan(self): self.disk_scan_complete.emit({}) # Dummy implementation
    def run(self): self.installation_finished.emit(False, "Backend Thread Not Implemented") # Dummy implementation
    def stop(self): pass

# --- Placeholder: Assume Archinstall Library Imports & Config ---
# The imports for archinstall components and the ARCHINSTALL_LIBRARY_AVAILABLE flag
# setup (from the previous response) need to be present in your full script.
ARCHINSTALL_LIBRARY_AVAILABLE = False # Set to True if imports succeed
DEFAULT_DESKTOP_ENVIRONMENT_PROFILE = "kde" 
try:
    # These are placeholders - real imports needed in the full script
    import archinstall 
    from archinstall.lib import locale, disk, installer, models
    if not hasattr(archinstall, 'arguments'): archinstall.arguments = {}
    if not hasattr(archinstall, 'storage'): archinstall.storage = {}
    # Define placeholder config keys if imports fail, so GUI doesn't crash
    ARG_DISK_CONFIG = 'disk_config'; ARG_LOCALE_CONFIG = 'locale_config'; ARG_ROOT_PASSWORD = '!root-password'
    ARG_USERS = '!users'; ARG_PROFILE_CONFIG = 'profile_config'; ARG_HOSTNAME = 'hostname'; ARG_PACKAGES = 'packages'; ARG_BOOTLOADER = 'bootloader'
    ARG_TIMEZONE = 'timezone'; ARG_KERNE = 'kernels'; ARG_NTP = 'ntp'; ARG_SWAP = 'swap'; ARG_ENCRYPTION = 'disk_encryption'

    ARCHINSTALL_LIBRARY_AVAILABLE = True # Assume success for demo if imports don't crash
except ImportError:
    class ArchinstallError(Exception): pass # Dummy exception
    class Bootloader: pass # Dummy enum/class
    class DiskLayoutType: pass # Dummy enum/class
    class User: pass # Dummy class
    class LocaleConfiguration: pass # Dummy class
    class ProfileConfiguration: pass # Dummy class
    class DiskLayoutConfiguration: pass # Dummy class
    # Define dummy args if imports fail
    ARG_DISK_CONFIG = 'disk_config'; ARG_LOCALE_CONFIG = 'locale_config'; ARG_ROOT_PASSWORD = '!root-password'
    ARG_USERS = '!users'; ARG_PROFILE_CONFIG = 'profile_config'; ARG_HOSTNAME = 'hostname'; ARG_PACKAGES = 'packages'; ARG_BOOTLOADER = 'bootloader'
    ARG_TIMEZONE = 'timezone'; ARG_KERNE = 'kernels'; ARG_NTP = 'ntp'; ARG_SWAP = 'swap'; ARG_ENCRYPTION = 'disk_encryption'


APP_CATEGORIES = { # Keep user's categories
    "Daily Use": ["firefox", "vlc", "gwenview", "okular", "libreoffice-still", "ark", "kate"],
    "Programming": ["git", "code", "python", "gcc", "gdb", "base-devel"],
    "Gaming": ["steam", "lutris", "wine", "noto-fonts-cjk"],
    "Education": ["gcompris-qt", "kgeography", "stellarium", "kalgebra"]
}
def check_root(): return os.geteuid() == 0

# --- Main Application Window (GUI Code) ---
class MaiBloomInstallerApp(QWidget):
    """PyQt5 GUI for the Mai Bloom OS Installer using Archinstall library."""
    
    def __init__(self):
        super().__init__()
        # self.installation_settings_for_gui = {} # Not strictly needed if populating global args
        self.installer_thread = None # Holds the background installation thread
        
        # Use a helper instance for non-threaded calls to the engine (like disk scan)
        # This assumes InstallerEngineThread has methods safe to call from GUI thread.
        self._engine_helper = InstallerEngineThread({}) 
        self._engine_helper.disk_scan_complete.connect(self.on_disk_scan_complete)
        self._engine_helper.installation_log.connect(self.update_log_output) 
        
        self.init_ui() # Setup the user interface
        self.update_log_output("Welcome to Mai Bloom OS Installer!")
        
        # Check if archinstall library is usable and inform user
        if not ARCHINSTALL_LIBRARY_AVAILABLE:
             self.update_log_output("CRITICAL ERROR: Archinstall library not loaded. Installation impossible.", "ERROR")
             QMessageBox.critical(self, "Startup Error", "Failed to load essential Archinstall library components.\nPlease ensure Archinstall is correctly installed and accessible via Python.\nThe application cannot continue.")
             self.install_button.setEnabled(False)
             self.scan_disks_button.setEnabled(False)
        else:
             self.update_log_output("Archinstall library loaded successfully.")
             self.trigger_disk_scan() # Trigger initial scan

    def init_ui(self):
        """Sets up the graphical user interface."""
        self.setWindowTitle(f'Mai Bloom OS Installer ({DEFAULT_DESKTOP_ENVIRONMENT_PROFILE} via Archinstall Lib)')
        self.setGeometry(100, 100, 850, 700) # Window size and position
        overall_layout = QVBoxLayout(self) # Main vertical layout

        # --- Top Title ---
        title_label = QLabel(f"<b>Install Mai Bloom OS ({DEFAULT_DESKTOP_ENVIRONMENT_PROFILE})</b>")
        title_label.setAlignment(Qt.AlignCenter)
        overall_layout.addWidget(title_label)
        overall_layout.addWidget(QLabel("<small>This installer uses the <b>archinstall</b> library directly for setup.</small>"))
        
        # --- Main Area (Splitter: Controls | Log) ---
        splitter = QSplitter(Qt.Horizontal)
        overall_layout.addWidget(splitter)

        # --- Left Pane: Controls ---
        controls_widget = QWidget()
        controls_layout = QVBoxLayout(controls_widget)

        # 1. Disk Setup GroupBox
        disk_group = QGroupBox("1. Disk Selection & Preparation")
        disk_layout_vbox = QVBoxLayout()
        self.scan_disks_button = QPushButton("Scan for Disks")
        self.scan_disks_button.setToolTip("Scan the system for installable disk drives.")
        self.scan_disks_button.clicked.connect(self.trigger_disk_scan)
        disk_layout_vbox.addWidget(self.scan_disks_button)
        self.disk_combo = QComboBox()
        self.disk_combo.setToolTip("Select the target disk for installation.")
        disk_layout_vbox.addLayout(self.create_form_row("Target Disk:", self.disk_combo))
        self.wipe_disk_checkbox = QCheckBox("Wipe disk & auto-configure standard layout")
        self.wipe_disk_checkbox.setChecked(True)
        self.wipe_disk_checkbox.setToolTip("Let archinstall erase and partition the disk automatically.\nRequires correct implementation of DiskLayoutConfiguration object creation.")
        disk_layout_vbox.addWidget(self.wipe_disk_checkbox)
        disk_group.setLayout(disk_layout_vbox)
        controls_layout.addWidget(disk_group)

        # 2. System & User Configuration GroupBox
        system_group = QGroupBox("2. System & User Details"); 
        system_layout_grid = QGridLayout()
        self.hostname_input = QLineEdit("maibloom-os")
        self.hostname_input.setToolTip("Set the computer's network name.")
        system_layout_grid.addWidget(QLabel("Hostname:"), 0, 0); system_layout_grid.addWidget(self.hostname_input, 0, 1)
        self.username_input = QLineEdit("maiuser")
        self.username_input.setToolTip("Enter the desired username for the main user.")
        system_layout_grid.addWidget(QLabel("Username:"), 1, 0); system_layout_grid.addWidget(self.username_input, 1, 1)
        self.password_input = QLineEdit(); self.password_input.setPlaceholderText("User & Root Password"); self.password_input.setEchoMode(QLineEdit.Password)
        self.password_input.setToolTip("Set the password for both the main user and the root account.")
        system_layout_grid.addWidget(QLabel("Password (User+Root):"), 2, 0); system_layout_grid.addWidget(self.password_input, 2, 1)
        self.locale_input = QLineEdit("en_US.UTF-8"); self.locale_input.setToolTip("Set the system language and encoding (e.g., en_US.UTF-8).")
        system_layout_grid.addWidget(QLabel("Locale:"), 3,0); system_layout_grid.addWidget(self.locale_input, 3,1)
        self.kb_layout_input = QLineEdit("us"); self.kb_layout_input.setToolTip("Set the keyboard layout (e.g., us, uk, de).")
        system_layout_grid.addWidget(QLabel("Keyboard Layout:"), 4,0); system_layout_grid.addWidget(self.kb_layout_input, 4,1)
        self.timezone_input = QLineEdit("UTC"); self.timezone_input.setToolTip("Set the timezone (e.g., UTC, America/New_York, Europe/Paris).")
        system_layout_grid.addWidget(QLabel("Timezone:"), 5,0); system_layout_grid.addWidget(self.timezone_input, 5,1)
        system_group.setLayout(system_layout_grid)
        controls_layout.addWidget(system_group)
        
        # 3. Additional Applications GroupBox
        app_group = QGroupBox(f"3. Additional Applications (on top of {DEFAULT_DESKTOP_ENVIRONMENT_PROFILE})")
        app_layout_grid = QGridLayout()
        self.app_category_checkboxes = {}
        row, col = 0,0
        for cat_name in APP_CATEGORIES.keys():
            self.app_category_checkboxes[cat_name] = QCheckBox(f"{cat_name}")
            self.app_category_checkboxes[cat_name].setToolTip(f"Install: {', '.join(APP_CATEGORIES[cat_name][:3])}...")
            app_layout_grid.addWidget(self.app_category_checkboxes[cat_name], row, col)
            col +=1
            if col > 1: col = 0; row +=1 # 2 checkboxes per row
        app_group.setLayout(app_layout_grid)
        controls_layout.addWidget(app_group)
        
        # Add stretch to push controls up
        controls_layout.addStretch(1) 
        # Add controls widget to the left pane of splitter
        splitter.addWidget(controls_widget)

        # --- Right Pane: Log Output ---
        log_group_box = QGroupBox("Installation Log")
        log_layout_vbox = QVBoxLayout()
        self.log_output = QTextEdit()
        self.log_output.setReadOnly(True)
        self.log_output.setLineWrapMode(QTextEdit.NoWrap) # Easier to read logs
        self.log_output.setStyleSheet("font-family: monospace;") # Monospace font good for logs
        log_layout_vbox.addWidget(self.log_output)
        log_group_box.setLayout(log_layout_vbox)
        # Add log widget to the right pane of splitter
        splitter.addWidget(log_group_box)
        
        # Set initial sizes for the splitter panes
        splitter.setSizes([400, 450]) 
        
        # --- Bottom: Install Button ---
        self.install_button = QPushButton(f"Install Mai Bloom OS ({DEFAULT_DESKTOP_ENVIRONMENT_PROFILE})")
        self.install_button.setStyleSheet("background-color: lightblue; padding: 10px; font-weight: bold;")
        self.install_button.setToolTip("Begin installation using the settings above.")
        self.install_button.clicked.connect(self.start_installation)
        # Center the button horizontally
        button_layout = QHBoxLayout(); button_layout.addStretch(); button_layout.addWidget(self.install_button); button_layout.addStretch()
        overall_layout.addLayout(button_layout)

    def create_form_row(self, label_text, widget):
        """Helper method to create a standard Label + Widget horizontal layout."""
        row_layout = QHBoxLayout()
        label = QLabel(label_text)
        label.setFixedWidth(120) # Consistent label width
        row_layout.addWidget(label)
        row_layout.addWidget(widget)
        return row_layout

    def trigger_disk_scan(self):
        """Initiates disk scan using archinstall library helper."""
        if not ARCHINSTALL_LIBRARY_AVAILABLE:
            self.update_log_output("Disk Scan unavailable: Archinstall library not loaded.", "ERROR")
            return
        self.update_log_output("GUI: Requesting disk scan via archinstall library...")
        self.scan_disks_button.setEnabled(False)
        try:
            # Calls run_disk_scan on the helper instance (runs in GUI thread)
            # User MUST ensure the underlying archinstall function is implemented in run_disk_scan
            self._engine_helper.run_disk_scan() 
        except Exception as e: # Catch errors during the call setup itself
             self.update_log_output(f"Failed to initiate disk scan: {e}", "ERROR")
             self.update_log_output(traceback.format_exc(), "ERROR")
             QMessageBox.critical(self, "Disk Scan Error", f"Failed to start disk scan: {e}")
             self.scan_disks_button.setEnabled(True) # Re-enable button on error

    def on_disk_scan_complete(self, disks_data):
        """Slot to handle the result of the disk scan signal."""
        self.update_log_output(f"GUI: Disk scan complete. Populating {len(disks_data)} disk(s).")
        self.disk_combo.clear()
        if disks_data:
            # Sort disks by path for consistent order
            for path_key, info_dict in sorted(disks_data.items()): 
                display_text = f"{path_key} - {info_dict.get('model', 'N/A')} ({info_dict.get('size', 'N/A')})"
                self.disk_combo.addItem(display_text, userData=path_key) # Store path as user data
        else:
            self.update_log_output("GUI: No suitable disks found by scan.", "WARN")
        self.scan_disks_button.setEnabled(True) # Re-enable button

    def update_log_output(self, message, level="INFO"):
        """Appends a message to the GUI log view."""
        prefix = f"[{level}] " if level != "INFO" else ""
        self.log_output.append(prefix + message)
        self.log_output.ensureCursorVisible() # Auto-scroll
        if level not in ["DEBUG", "CMD_OUT", "CMD_ERR"]: # Avoid GUI freeze on high-frequency logs
             QApplication.processEvents()

    def gather_settings_and_populate_args(self) -> bool:
        """
        Gathers settings from GUI and populates archinstall.arguments.
        Returns True if successful, False otherwise.
        !!! CRITICAL USER IMPLEMENTATION AREA !!!
        Requires research into archinstall's API for object creation.
        """
        self.update_log_output("Gathering settings and preparing archinstall arguments...")
        gui_settings = {}
        
        # --- Disk ---
        selected_disk_index = self.disk_combo.currentIndex()
        if selected_disk_index < 0: QMessageBox.warning(self, "Input Error", "Please select a target disk."); return False
        target_disk_path = self.disk_combo.itemData(selected_disk_index)
        if not target_disk_path: QMessageBox.warning(self, "Input Error", "Invalid disk selected."); return False
        gui_settings["target_disk_path"] = target_disk_path
        gui_settings["wipe_disk"] = self.wipe_disk_checkbox.isChecked()

        # --- System & User ---
        gui_settings["hostname"] = self.hostname_input.text().strip()
        gui_settings["username"] = self.username_input.text().strip()
        gui_settings["password"] = self.password_input.text() 
        gui_settings["locale"] = self.locale_input.text().strip()
        gui_settings["kb_layout"] = self.kb_layout_input.text().strip()
        gui_settings["timezone"] = self.timezone_input.text().strip()
        
        # --- Validation ---
        if not all([gui_settings["hostname"], gui_settings["username"], gui_settings["password"],
                    gui_settings["locale"], gui_settings["kb_layout"], gui_settings["timezone"]]):
            QMessageBox.warning(self, "Input Error", "Please fill all System & User fields."); return False

        # --- Profile & Packages ---
        gui_settings["profile"] = DEFAULT_DESKTOP_ENVIRONMENT_PROFILE 
        additional_packages = []
        for cat_name, checkbox_widget in self.app_category_checkboxes.items():
            if checkbox_widget.isChecked():
                additional_packages.extend(APP_CATEGORIES.get(cat_name, []))
        # Add essentials mentioned in user's snippet/common sense
        base_essentials = ["sudo", "nano"] 
        additional_packages = list(set(additional_packages + base_essentials))
        gui_settings["additional_packages"] = additional_packages

        # --- Populate archinstall.arguments ---
        try:
            # We need the global 'archinstall' module reference if it was imported successfully
            if not ARCHINSTALL_LIBRARY_AVAILABLE:
                 raise ArchinstallError("Cannot populate arguments, library not loaded.")
                 
            args = archinstall.arguments # Get reference to the global dictionary

            # Simple arguments
            args[ARG_HOSTNAME] = gui_settings["hostname"]
            args[ARG_ROOT_PASSWORD] = gui_settings["password"]
            args[ARG_TIMEZONE] = gui_settings["timezone"]
            args[ARG_KERNE] = ['linux'] # Default kernel
            args[ARG_NTP] = True
            args[ARG_SWAP] = True 
            args[ARG_PACKAGES] = gui_settings["additional_packages"]
            
            # Bootloader (use enum from archinstall.lib.models if possible)
            is_efi = os.path.exists("/sys/firmware/efi")
            args[ARG_BOOTLOADER] = models.Bootloader.SystemdBoot if is_efi else models.Bootloader.Grub
            
            # --- Complex Arguments Requiring Object Instantiation (USER MUST IMPLEMENT) ---
            
            # LocaleConfiguration
            self.update_log_output("TODO: Create archinstall.lib.locale.LocaleConfiguration object.", "WARN")
            # args[ARG_LOCALE_CONFIG] = locale.LocaleConfiguration(
            #     kb_layout=gui_settings["kb_layout"], 
            #     sys_lang=gui_settings["locale"], # Or split off encoding? Check class init.
            #     sys_enc='UTF-8' 
            # )
            # Placeholder if class structure unknown:
            args[ARG_LOCALE_CONFIG] = {'kb_layout': gui_settings["kb_layout"], 'sys_lang': gui_settings["locale"], 'sys_enc': 'UTF-8'}
            
            # User list
            self.update_log_output("TODO: Create list of archinstall.lib.models.User objects.", "WARN")
            # args[ARG_USERS] = [
            #     models.User(gui_settings["username"], gui_settings["password"], sudo=True)
            # ]
            # Placeholder if class structure unknown:
            args[ARG_USERS] = [{'username': gui_settings["username"], 'password': gui_settings["password"], 'sudo': True}]
            
            # ProfileConfiguration
            self.update_log_output("TODO: Create archinstall.lib.models.ProfileConfiguration object.", "WARN")
            # This might involve getting a profile object first using profile_handler
            # profile_obj = profile_handler.get_profile(gui_settings["profile"]) # Hypothetical
            # args[ARG_PROFILE_CONFIG] = models.ProfileConfiguration(profile=profile_obj) # Hypothetical
            # Placeholder if class structure unknown:
            args[ARG_PROFILE_CONFIG] = {'profile': {'main': gui_settings["profile"]}}

            # DiskLayoutConfiguration (Most complex)
            self.update_log_output("TODO: Create archinstall.lib.disk.DiskLayoutConfiguration object.", "CRITICAL")
            # This requires understanding how archinstall represents disk layouts, partitions, filesystems.
            # It depends heavily on whether wipe_disk is True and what layout is desired.
            # This placeholder is almost certainly **incorrect** and needs full implementation.
            if gui_settings["wipe_disk"]:
                args[ARG_DISK_CONFIG] = disk.DiskLayoutConfiguration( # Hypothetical instantiation
                    config_type=disk.DiskLayoutType.Default, # Value needs verification
                    device=Path(gui_settings["target_disk_path"]), 
                    wipe_mode=disk.WipeMode.Secure # Example, check available wipe modes
                    # ... potentially many other parameters for default layout ...
                )
                self.log("Set disk config (Wipe/Auto) - PLACEHOLDER NEEDS REAL IMPLEMENTATION", "WARN")
            else:
                args[ARG_DISK_CONFIG] = disk.DiskLayoutConfiguration(
                    config_type=disk.DiskLayoutType.Pre_mount # Value needs verification
                    # ... parameters needed for pre-mount config ...
                )
                self.log("Set disk config (Use Existing) - PLACEHOLDER NEEDS REAL IMPLEMENTATION", "WARN")

            # Optional configurations (set to None or default objects)
            args[ARG_ENCRYPTION] = None 
            # args[ARG_NETWORK_CONFIG] = models.NetworkConfiguration(...) 
            # args[ARG_AUDIO_CONFIG] = models.AudioConfiguration(...)

            # --- End Configuration Population ---

            self.update_log_output("Attempted to populate archinstall.arguments.", "INFO")
            self.update_log_output(f"  Keys set: {list(args.keys())}", "DEBUG")
            # Optionally print the structure for debugging (can be very verbose)
            # import pprint; self.log(f"Arguments:\n{pprint.pformat(args)}", "DEBUG")
            return True

        except ImportError as e:
             # Should be caught at startup, but handle here too
             self.update_log_output(f"Import Error during argument preparation: {e}", "ERROR")
             self.update_log_output(traceback.format_exc(), "ERROR")
             QMessageBox.critical(self, "Library Error", f"Missing component from archinstall library: {e}")
             return False
        except Exception as e: # Catch errors during object creation etc.
            self.update_log_output(f"Error preparing archinstall arguments: {e}", "ERROR")
            self.update_log_output(traceback.format_exc(), "ERROR")
            QMessageBox.critical(self, "Configuration Error", f"Failed to prepare installation configuration objects: {e}\n\nCheck archinstall API/version.")
            return False


    def start_installation(self):
        """Gathers settings, populates archinstall.arguments, confirms, and starts thread."""
        if not ARCHINSTALL_LIBRARY_AVAILABLE:
             QMessageBox.critical(self, "Error", "Archinstall library not loaded. Cannot install.")
             return

        # Populate the global arguments dictionary using the dedicated method
        if not self.gather_settings_and_populate_args():
             self.update_log_output("Configuration gathering/population failed. Installation aborted.", "ERROR")
             return 

        # Confirmation Dialog - Retrieve data directly from archinstall.arguments for display
        try:
             # Safely get display values, using .get() with defaults
             target_disk_obj = archinstall.arguments.get(ARG_DISK_CONFIG)
             target_disk_path = getattr(target_disk_obj, 'device', 'N/A') if target_disk_obj else 'N/A' # Example if DiskLayoutConfig has .device attr
             # This might be simpler if target_disk_path was stored separately or retrieved differently
             # Fallback using the combo box value if object parsing failed
             if target_disk_path == 'N/A' and self.disk_combo.currentIndex() >= 0:
                  target_disk_path = self.disk_combo.itemData(self.disk_combo.currentIndex())

             wipe_disk_val = getattr(target_disk_obj, 'wipe', False) if target_disk_obj else False # Example if it has .wipe attr
             # Fallback
             if target_disk_obj is None: wipe_disk_val = self.wipe_disk_checkbox.isChecked()
                 
             profile_name = getattr(archinstall.arguments.get(ARG_PROFILE_CONFIG), 'profile_name_attribute', DEFAULT_DESKTOP_ENVIRONMENT_PROFILE) # Example, adjust attribute name
        except Exception as e:
             self.update_log_output(f"Error retrieving arguments for confirmation dialog: {e}", "WARN")
             target_disk_path = "Error Retrieving"
             wipe_disk_val = False
             profile_name = "Error Retrieving"

        wipe_warning = "YES (ENTIRE DISK WILL BE ERASED!)" if wipe_disk_val else "NO (Advanced - Using existing partitions)"
        confirm_msg = (f"Ready to install Mai Bloom OS ({profile_name}) using the archinstall library:\n\n"
                       f"  - Target Disk: {target_disk_path}\n"
                       f"  - Wipe Disk & Auto-Configure: {wipe_warning}\n\n"
                       "PROCEED WITH INSTALLATION?")
        
        reply = QMessageBox.question(self, 'Confirm Installation', confirm_msg, QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if reply == QMessageBox.No:
            self.update_log_output("Installation cancelled by user.")
            return

        # Start the installation thread
        self.install_button.setEnabled(False); self.scan_disks_button.setEnabled(False)
        self.log_output.clear(); self.update_log_output("Starting installation via archinstall library...")

        # Pass the populated arguments dictionary if the thread needs it, 
        # though the current thread design reads the global directly.
        self.installer_thread = InstallerEngineThread(archinstall.arguments) 
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
        try:
            mount_point = archinstall.storage.get('MOUNT_POINT')
            if mount_point and Path(mount_point).is_mount(): # Check if it's actually mounted
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
        except Exception as e:
             self.update_log_output(f"Error during final unmount attempt: {e}", "WARN")


    def select_post_install_script(self): # Optional post-install script selector (not used by engine now)
        """Allows user to select an optional script."""
        options = QFileDialog.Options()
        filePath, _ = QFileDialog.getOpenFileName(self, "Select Optional Post-Installation Bash Script", "", "Bash Scripts (*.sh);;All Files (*)", options=options)
        # Currently, this script isn't passed to or used by the InstallerEngineThread.
        # You could modify the engine to run it using run_custom_user_commands if desired.
        if filePath:
            self.update_log_output(f"Optional post-install script selected: {filePath} (Note: Currently not executed by installer).")
        # Update label if needed: self.post_install_script_label.setText(...)


    def closeEvent(self, event): # Graceful exit handling
        """Handle window close event, attempt to stop thread if running."""
        if self.installer_thread and self.installer_thread.isRunning():
            reply = QMessageBox.question(self, 'Installation in Progress',
                                         "An installation is currently running. Stopping now may leave the system in an inconsistent state. Are you sure you want to exit?",
                                         QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
            if reply == QMessageBox.Yes:
                if hasattr(self.installer_thread, 'stop'):
                     self.installer_thread.stop() # Request thread to stop gracefully
                self.update_log_output("Attempting to wait for thread termination...")
                self.installer_thread.wait(2000) # Wait up to 2 seconds
                if self.installer_thread.isRunning():
                     self.update_log_output("Thread did not stop gracefully. Forcing exit.", "WARN")
                event.accept() # Close window
            else:
                event.ignore() # Keep window open
        else:
            event.accept() # Close window


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
    installer_gui = MaiBloomInstallerApp()
    installer_gui.show()
    sys.exit(app.exec_())

