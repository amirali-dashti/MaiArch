import sys import os from pathlib import Path

from PyQt5.QtWidgets import ( QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton, QFileDialog, QMessageBox, QComboBox, QCheckBox, QTextEdit, QTabWidget )

from archinstall import SysInfo from archinstall.lib.args import arch_config_handler from archinstall.lib.configuration import ConfigurationOutput from archinstall.lib.disk.filesystem import FilesystemHandler from archinstall.lib.installer import Installer, accessibility_tools_in_use, run_custom_user_commands from archinstall.lib.global_menu import GlobalMenu from archinstall.lib.interactions.general_conf import PostInstallationAction, ask_post_installation from archinstall.lib.models import Bootloader from archinstall.lib.models.device_model import DiskLayoutType, EncryptionType from archinstall.lib.models.users import User from archinstall.lib.profile.profiles_handler import profile_handler from archinstall.tui import Tui from archinstall.lib.output import info, error, debug

class MaiBloomOS(QMainWindow): def init(self): super().init() self.setWindowTitle("Mai Bloom OS Installer") self.setGeometry(100, 100, 800, 600)

self.tabs = QTabWidget()
    self.setCentralWidget(self.tabs)

    self.disk_tab = DiskConfigTab()
    self.user_tab = UserConfigTab()
    self.options_tab = OptionsTab()
    self.install_tab = InstallTab()

    self.tabs.addTab(self.disk_tab, "Disk")
    self.tabs.addTab(self.user_tab, "Users")
    self.tabs.addTab(self.options_tab, "Options")
    self.tabs.addTab(self.install_tab, "Install")

class DiskConfigTab(QWidget): def init(self): super().init() layout = QVBoxLayout()

# Mountpoint Selection
    mount_layout = QHBoxLayout()
    mount_layout.addWidget(QLabel("Mountpoint:"))
    self.mount_edit = QLineEdit()
    mount_layout.addWidget(self.mount_edit)
    browse_btn = QPushButton("Browse")
    browse_btn.clicked.connect(self.browse_mount)
    mount_layout.addWidget(browse_btn)
    layout.addLayout(mount_layout)

    # Encryption
    self.encrypt_check = QCheckBox("Enable Encryption")
    layout.addWidget(self.encrypt_check)

    self.setLayout(layout)

def browse_mount(self):
    directory = QFileDialog.getExistingDirectory(self, "Select Mountpoint")
    if directory:
        self.mount_edit.setText(directory)

class UserConfigTab(QWidget): def init(self): super().init() layout = QVBoxLayout()

layout.addWidget(QLabel("Root Password:"))
    self.root_pw = QLineEdit()
    self.root_pw.setEchoMode(QLineEdit.Password)
    layout.addWidget(self.root_pw)

    layout.addWidget(QLabel("New User Name:"))
    self.username = QLineEdit()
    layout.addWidget(self.username)

    layout.addWidget(QLabel("User Password:"))
    self.user_pw = QLineEdit()
    self.user_pw.setEchoMode(QLineEdit.Password)
    layout.addWidget(self.user_pw)

    self.setLayout(layout)

class OptionsTab(QWidget): def init(self): super().init() layout = QVBoxLayout()

layout.addWidget(QLabel("Bootloader:"))
    self.boot_combo = QComboBox()
    for bl in Bootloader:
        self.boot_combo.addItem(bl.name, bl)
    layout.addWidget(self.boot_combo)

    self.dry_run = QCheckBox("Dry Run")
    layout.addWidget(self.dry_run)
    self.silent = QCheckBox("Silent Mode")
    layout.addWidget(self.silent)
    self.setLayout(layout)

class InstallTab(QWidget): def init(self): super().init() layout = QVBoxLayout()

self.log_output = QTextEdit()
    self.log_output.setReadOnly(True)
    layout.addWidget(self.log_output)

    install_btn = QPushButton("Start Installation")
    install_btn.clicked.connect(self.start_install)
    layout.addWidget(install_btn)

    self.setLayout(layout)

def start_install(self):
    try:
        # Collect config from tabs
        mount = Path(
            self.parentWidget().disk_tab.mount_edit.text() or '/mnt')
        arch_config_handler.config.disk_config.mountpoint = mount
        arch_config_handler.config.disk_encryption = (
            EncryptionType.Luks if self.parentWidget().disk_tab.encrypt_check.isChecked()
            else EncryptionType.NoEncryption
        )

        # User config
        root_pw = self.parentWidget().user_tab.root_pw.text()
        if root_pw:
            arch_config_handler.config.root_enc_password = root_pw

        username = self.parentWidget().user_tab.username.text()
        user_pw = self.parentWidget().user_tab.user_pw.text()
        if username and user_pw:
            arch_config_handler.config.users = [User(username, user_pw, False)]

        # Options
        arch_config_handler.args.dry_run = self.parentWidget().options_tab.dry_run.isChecked()
        arch_config_handler.args.silent = self.parentWidget().options_tab.silent.isChecked()
        arch_config_handler.config.bootloader = self.parentWidget().options_tab.boot_combo.currentData()

        # Perform install
        config = ConfigurationOutput(arch_config_handler.config)
        config.write_debug()
        config.save()

        if not arch_config_handler.args.dry_run:
            fs_handler = FilesystemHandler(
                arch_config_handler.config.disk_config,
                arch_config_handler.config.disk_encryption,
            )
            fs_handler.perform_filesystem_operations()

        perform_installation(mount)
        QMessageBox.information(self, "Success", "Installation completed.")
    except Exception as e:
        error(f"Installation failed: {e}")
        QMessageBox.critical(self, "Error", str(e))

def perform_installation(mountpoint: Path) -> None: info("Starting installation...") # Copy the function body from existing script from archinstall.lib.models import Bootloader as BL from archinstall.lib.disk.utils import disk_layouts # ... include full implementation as needed ...

if name == 'main': app = QApplication(sys.argv) window = MaiBloomOS() window.show() sys.exit(app.exec_())

