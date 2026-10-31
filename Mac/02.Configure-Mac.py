#!/usr/bin/env python3
import argparse
import os
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

# Ask for the sudo password once up front, then keep sudo's credential cache fresh in
# the background until the script exits - so a long run never stops halfway to prompt
# again. Same approach as the keep-alive loop in Fedora/01.Setup-Fedora.sh. (Kept as a
# copy in each Mac script that needs it, so every script runs on its own.)
SUDO_REFRESH_SECONDS = 60


def start_sudo_keepalive():
    print("Some steps need administrator rights - enter your password once and the rest runs unattended.")
    if subprocess.run(["sudo", "-v"]).returncode != 0:
        sys.exit("sudo authentication failed - nothing was changed.")

    def refresh():
        while True:
            time.sleep(SUDO_REFRESH_SECONDS)
            subprocess.run(["sudo", "-n", "-v"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Daemon thread: it dies with the script, so the cache just ages out normally afterwards.
    threading.Thread(target=refresh, daemon=True).start()


TERMINAL_DIR = Path(__file__).resolve().parent / "Terminal"

RESTART_APPS = [
    "Activity Monitor",
    "Address Book",
    "Calendar",
    "cfprefsd",
    "Contacts",
    "Dock",
    "Finder",
    "Mail",
    "Messages",
    "Music",
    "Opera",
    "Photos",
    "Safari",
    "SizeUp",
    "Spectacle",
    "SystemUIServer",
    "Terminal",
    "TextEdit",
    "Transmission",
    "Tweetbot",
    "Twitter",
    "iCal",
]


def run(cmd):
    """Run a command; warn and continue on failure instead of aborting the whole script."""
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print(f"Warning: {' '.join(cmd)} exited with status {result.returncode}")
    return result.returncode == 0


def write_default(domain, key, kind, value, *, sudo=False, current_host=False):
    cmd = []
    if sudo:
        cmd += ["sudo"]
    cmd.append("defaults")
    if current_host:
        cmd.append("-currentHost")
    cmd += ["write", domain, key, f"-{kind}", str(value)]
    return run(cmd)


def configure_startup_chime():
    # StartupMute=%01 to mute, %00 to turn back on
    run(["sudo", "nvram", "StartupMute=%01"])


def configure_dock():
    write_default("com.apple.dock", "tilesize", "int", 48)
    write_default("com.apple.dock", "show-recents", "bool", "false")
    write_default("com.apple.dock", "show-process-indicators", "bool", "true")


def configure_finder():
    write_default("com.apple.finder", "ShowStatusBar", "bool", "true")
    write_default("NSGlobalDomain", "AppleShowAllExtensions", "bool", "true")
    write_default("com.apple.finder", "ShowPathbar", "bool", "true")
    write_default("com.apple.finder", "FXPreferredViewStyle", "string", "Nlsv")
    write_default("com.apple.finder", "_FXSortFoldersFirst", "bool", "true")
    write_default("com.apple.finder", "FXDefaultSearchScope", "string", "SCcf")
    write_default("com.apple.finder", "FXRemoveOldTrashItems", "bool", "true")
    write_default("com.apple.finder", "FXEnableExtensionChangeWarning", "bool", "false")
    write_default("NSGlobalDomain", "NSDocumentSaveNewDocumentsToCloud", "bool", "false")
    write_default("NSGlobalDomain", "NSToolbarTitleViewRolloverDelay", "float", 0)
    write_default("com.apple.finder", "WarnOnEmptyTrash", "bool", "false")
    # -dict-add (not -dict) so this merges into FXInfoPanesExpanded instead of replacing
    # it outright - a plain -dict would silently collapse any other Get Info panes you'd
    # expanded yourself (Comments, Name & Extension, Sharing & Permissions, etc.) back to
    # their default state, since -dict overwrites the whole stored dictionary.
    run(["defaults", "write", "com.apple.finder", "FXInfoPanesExpanded", "-dict-add", "General", "-bool", "true"])
    run(["defaults", "write", "com.apple.finder", "FXInfoPanesExpanded", "-dict-add", "OpenWith", "-bool", "true"])
    run(["defaults", "write", "com.apple.finder", "FXInfoPanesExpanded", "-dict-add", "Privileges", "-bool", "true"])
    # Avoid creating .DS_Store files on network or USB volumes
    write_default("com.apple.desktopservices", "DSDontWriteNetworkStores", "bool", "true")
    write_default("com.apple.desktopservices", "DSDontWriteUSBStores", "bool", "true")


FINDER_VIEW_SETTINGS_KEYS = [
    "StandardViewSettings",
    "FK_StandardViewSettings",
    "ICloudViewSettings",
    "SearchViewSettings",
    "FK_SearchViewSettings",
    "ComputerViewSettings",
    "TrashViewSettings",
]

# Skipped when hunting for .DS_Store files - slow to walk and never browsed in Finder
DS_STORE_SKIP_DIRS = {"node_modules", ".git", ".Trash"}


def reset_finder_view_settings():
    """Clear saved per-folder and default view settings so FXPreferredViewStyle applies everywhere."""
    # Finder's saved "Use as Defaults" view options. Deleting them drops Finder back to
    # the stock defaults, with FXPreferredViewStyle (list view) as the view style.
    for key in FINDER_VIEW_SETTINGS_KEYS:
        subprocess.run(["defaults", "delete", "com.apple.finder", key],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Each folder's own view settings live in the .DS_Store file inside it. ~/Library is
    # skipped apart from iCloud Drive; ~/Desktop/.DS_Store is kept so desktop icon
    # positions survive.
    home = Path.home()
    keep = home / "Desktop/.DS_Store"
    removed = 0
    for root in [home, home / "Library/Mobile Documents"]:
        for dirpath, dirnames, filenames in os.walk(root):
            current = Path(dirpath)
            dirnames[:] = [
                d for d in dirnames
                if d not in DS_STORE_SKIP_DIRS and current / d != home / "Library"
            ]
            if ".DS_Store" in filenames and current / ".DS_Store" != keep:
                try:
                    (current / ".DS_Store").unlink()
                    removed += 1
                except OSError:
                    pass
    print(f"Removed {removed} .DS_Store files")

    # SIGKILL rather than a normal quit so Finder can't write its in-memory view settings
    # back out on the way down; launchd relaunches it straight away.
    subprocess.run(["killall", "-KILL", "Finder"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def configure_desktop():
    write_default("com.apple.finder", "_FXSortFoldersFirstOnDesktop", "bool", "true")


def configure_window_corners():
    # Smaller than Tahoe's default of 26 for less rounded window corners. Undocumented key.
    write_default("NSGlobalDomain", "NSConvolutionOverride1", "float", 10)
    # Revert to the traditional integrated sidebar instead of the floating appearance
    # that shipped alongside the rounder corners.
    write_default("NSGlobalDomain", "NSSplitViewItemSidebarDefaultsToFloatingAppearance", "bool", "false")


def configure_menu_bar():
    write_default("com.apple.menuextra.clock", "DateFormat", "string", "EEE d MMM HH:mm:ss")
    write_default("com.apple.menuextra.clock", "Show24Hour", "bool", "true")


def configure_time_format():
    # System-wide 24-hour time (System Settings > General > Date & Time > 24-hour time)
    write_default("NSGlobalDomain", "AppleICUForce24HourTime", "bool", "true")


def configure_textedit():
    # TextEdit is sandboxed, so it reads prefs from its container rather than
    # ~/Library/Preferences. The container only exists after the first launch - before
    # that, defaults writes land in ~/Library/Preferences and TextEdit ignores them.
    # Launch it once in the background so the container exists.
    container = Path.home() / "Library/Containers/com.apple.TextEdit"
    if not container.exists():
        run(["open", "-g", "-j", "-a", "TextEdit"])
        for _ in range(20):
            if container.exists():
                break
            time.sleep(0.5)
        subprocess.run(["killall", "TextEdit"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1)

    ok = write_default("com.apple.TextEdit", "RichText", "bool", "false")
    ok &= write_default("com.apple.TextEdit", "NSShowAppCentricOpenPanelInsteadOfUntitledFile", "bool", "false")
    if not ok:
        # macOS blocks writing into another app's container unless the app running
        # this script has Full Disk Access.
        print("TextEdit settings not applied: give your terminal app Full Disk Access in "
              "System Settings > Privacy & Security > Full Disk Access, then re-run.")


def configure_music():
    write_default("com.apple.Music", "userWantsPlaybackNotifications", "bool", "true")


def configure_mail():
    write_default("com.apple.mail", "DisableReplyAnimations", "bool", "true")
    write_default("com.apple.mail", "DisableSendAnimations", "bool", "true")
    run(["defaults", "write", "com.apple.mail", "DraftsViewerAttributes",
         "-dict-add", "DisplayInThreadedMode", "-string", "yes"])
    run(["defaults", "write", "com.apple.mail", "DraftsViewerAttributes",
         "-dict-add", "SortedDescending", "-string", "yes"])
    run(["defaults", "write", "com.apple.mail", "DraftsViewerAttributes",
         "-dict-add", "SortOrder", "-string", "received-date"])


def configure_login_window():
    write_default("com.apple.loginwindow", "RetriesUntilHint", "int", 0)
    write_default("com.apple.loginwindow", "TALLogoutSavesState", "bool", "false")
    # Display a custom message on the login window. This is the built-in macOS
    # banner text and is the supported way to show a message to users.
    write_default("/Library/Preferences/com.apple.loginwindow", "LoginwindowText", "string",
                  "This Mac is managed by desktopconfigs.", sudo=True)
    # Reveal IP address, hostname, OS version, etc. when clicking the clock
    # on the login window. This isn't a typed value - "HostName" is the
    # literal sentinel defaults expects here, not a real hostname.
    run(["sudo", "defaults", "write", "/Library/Preferences/com.apple.loginwindow",
         "AdminHostInfo", "HostName"])


def configure_trackpad():
    # Enable tap to click for this user and for the login screen
    write_default("com.apple.driver.AppleBluetoothMultitouch.trackpad", "Clicking", "bool", "true")
    write_default("NSGlobalDomain", "com.apple.mouse.tapBehavior", "int", 1, current_host=True)
    write_default("NSGlobalDomain", "com.apple.mouse.tapBehavior", "int", 1)

    # Map bottom right corner to right-click
    write_default("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadCornerSecondaryClick", "int", 2)
    write_default("com.apple.driver.AppleBluetoothMultitouch.trackpad", "TrackpadRightClick", "bool", "true")
    write_default("NSGlobalDomain", "com.apple.trackpad.trackpadCornerClickBehavior", "int", 1, current_host=True)
    write_default("NSGlobalDomain", "com.apple.trackpad.enableSecondaryClick", "bool", "true", current_host=True)


def configure_software_update():
    plist = "/Library/Preferences/com.apple.SoftwareUpdate.plist"
    write_default(plist, "AutomaticallyInstallMacOSUpdates", "bool", "true", sudo=True)
    write_default(plist, "AutomaticCheckEnabled", "bool", "true", sudo=True)
    write_default(plist, "AutomaticDownload", "bool", "true", sudo=True)
    write_default(plist, "CriticalUpdateInstall", "bool", "true", sudo=True)
    write_default(plist, "ConfigDataInstall", "bool", "true", sudo=True)
    write_default("/Library/Preferences/com.apple.commerce.plist", "AutoUpdate", "bool", "true", sudo=True)


def configure_printing():
    # Automatically quit the printer app once print jobs complete
    write_default("com.apple.print.PrintingPrefs", "Quit When Finished", "bool", "true")
    # Expand print panel by default
    write_default("NSGlobalDomain", "PMPrintingExpandedStateForPrint", "bool", "true")
    write_default("NSGlobalDomain", "PMPrintingExpandedStateForPrint2", "bool", "true")


def configure_multi_app_settings():
    # Always expand save dialog
    write_default("NSGlobalDomain", "NSNavPanelExpandedStateForSaveMode", "bool", "true")
    # Prevent Photos.app from opening when a device is plugged in
    write_default("com.apple.ImageCapture", "disableHotPlug", "bool", "true")


def configure_firewall():
    run(["sudo", "/usr/libexec/ApplicationFirewall/socketfilterfw", "--setglobalstate", "on"])
    run(["sudo", "/usr/libexec/ApplicationFirewall/socketfilterfw", "--setstealthmode", "on"])


def configure_misc():
    # Save to disk (not to iCloud) by default
    write_default("NSGlobalDomain", "NSDocumentSaveNewDocumentsToCloud", "bool", "false")
    # Enable full keyboard access for all controls, e.g. Tab in modal dialogs
    write_default("NSGlobalDomain", "AppleKeyboardUIMode", "int", 3)
    # Enable AirDrop over Ethernet and on unsupported Macs
    write_default("com.apple.NetworkBrowser", "BrowseAllInterfaces", "bool", "true")


def install_dotfile(source, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, dest)
    print(f"Installed {dest}")


def install_dotdir(source, dest, pattern="*.sh"):
    dest.mkdir(parents=True, exist_ok=True)
    for f in sorted(source.glob(pattern)):
        shutil.copyfile(f, dest / f.name)
    print(f"Installed {dest}/{pattern}")


def install_terminal_profile(source, name):
    plist = str(Path.home() / "Library/Preferences/com.apple.Terminal.plist")
    entry = f":Window Settings:{name}"
    # Delete first so re-running is idempotent instead of merging duplicate keys
    # into an already-populated profile; failure here just means it's not there yet.
    subprocess.run(
        ["/usr/libexec/PlistBuddy", "-c", f'Delete "{entry}"', plist],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    if run(["/usr/libexec/PlistBuddy",
            "-c", f'Add "{entry}" dict',
            "-c", f'Merge {source} "{entry}"',
            plist]):
        print(f"Installed Terminal profile '{name}'")


def configure_terminal():
    # Enable "focus follows mouse" for Terminal.app and all X11 apps
    write_default("com.apple.terminal", "FocusFollowsMouse", "bool", "true")
    write_default("org.x.X11", "wm_ffm", "bool", "true")

    install_dotfile(TERMINAL_DIR / ".zshrc", Path.home() / ".zshrc")
    install_dotdir(TERMINAL_DIR / ".bash_aliases", Path.home() / ".bash_aliases")
    install_dotfile(
        TERMINAL_DIR / "Microsoft.PowerShell_profile.ps1",
        Path.home() / ".config/powershell/Microsoft.PowerShell_profile.ps1",
    )
    install_terminal_profile(TERMINAL_DIR / "PowerShell.terminal", "PowerShell")


# ---------------------------------------------------------------------------
# Folder redirection - move Desktop/Documents/Downloads into a cloud storage
# folder and leave symlinks behind, so they sync. Optional: --cloudstorage NAME,
# or you're asked (Enter = skip).
# ---------------------------------------------------------------------------

CLOUD_PROVIDERS = ["OneDrive", "Proton Drive", "iCloud Drive"]

# local folder name -> path relative to the cloud storage root.
# Downloads isn't one of OneDrive's standard synced folders, so it lives
# nested under Documents in the cloud instead of being a top-level folder.
REDIRECTIONS = {
    "Desktop": "Desktop",
    "Documents": "Documents",
    "Downloads": "Documents/Downloads",
}


def parse_cloud_provider(value):
    """Match --cloudstorage loosely: 'onedrive', 'OneDrive', 'proton', 'icloud', 'none'..."""
    key = value.lower().replace(" ", "").replace("-", "")
    if key in ("none", "skip", "no"):
        return None
    for provider in CLOUD_PROVIDERS:
        name = provider.lower().replace(" ", "")
        if key in (name, name.removesuffix("drive")):
            return provider
    choices = ", ".join(f"'{p}'" for p in CLOUD_PROVIDERS)
    raise argparse.ArgumentTypeError(f"unknown cloud storage '{value}' - use {choices} or 'None'")


def prompt_for_provider():
    while True:
        print("\nRedirect Desktop/Documents/Downloads into cloud storage?")
        print("  0) None - leave the folders where they are")
        for number, provider in enumerate(CLOUD_PROVIDERS, start=1):
            print(f"  {number}) {provider}")
        choice = input("Choice [0]: ").strip() or "0"
        if choice == "0":
            return None
        if choice.isdigit() and 1 <= int(choice) <= len(CLOUD_PROVIDERS):
            return CLOUD_PROVIDERS[int(choice) - 1]
        print(f"Invalid selection: {choice!r}.", file=sys.stderr)


def find_cloud_root(provider, home):
    """The provider's local sync folder, or None if it isn't there (app not installed/signed in)."""
    cloud_storage = home / "Library" / "CloudStorage"
    if provider == "OneDrive":
        # Current OneDrive syncs to ~/Library/CloudStorage/OneDrive-Personal (or
        # OneDrive-<Company>); older versions used ~/OneDrive.
        candidates = [cloud_storage / "OneDrive-Personal", home / "OneDrive",
                      home / "OneDrive - Personal"]
        if cloud_storage.exists():
            candidates += sorted(cloud_storage.glob("OneDrive-*"))
    elif provider == "Proton Drive":
        candidates = [cloud_storage / "ProtonDrive", cloud_storage / "Proton Drive", home / "Proton Drive"]
        if cloud_storage.exists():
            candidates += sorted(cloud_storage.glob("*Proton*"))
    else:
        candidates = [home / "Library" / "Mobile Documents" / "com~apple~CloudDocs", home / "iCloud Drive"]

    for candidate in candidates:
        if candidate.is_dir():
            return candidate
    return None


def redirect_folder(name, cloud_relative_path, home, cloud_root):
    local = home / name
    cloud = cloud_root / cloud_relative_path

    if local.is_symlink():
        print(f"{local} is already a symlink, skipping")
        return

    cloud.mkdir(parents=True, exist_ok=True)

    if local.is_dir():
        items = list(local.iterdir())
        print(f"Moving {len(items)} item(s) from {local} to {cloud}")
        for item in items:
            dest = cloud / item.name
            if dest.exists():
                print(f"Skipping {item.name}: already exists at {dest}", file=sys.stderr)
                continue
            shutil.move(str(item), str(dest))

        remaining = list(local.iterdir())
        if remaining:
            print(
                f"Refusing to remove {local}: {len(remaining)} item(s) could not be moved "
                "(name conflicts with the cloud folder)",
                file=sys.stderr,
            )
            return

        print(f"Removing {local}")
        local.rmdir()
    elif local.exists():
        print(f"{local} exists but isn't a directory, skipping", file=sys.stderr)
        return

    print(f"Linking {local} -> {cloud}")
    local.symlink_to(cloud)


def configure_folder_redirection(provider):
    if provider is None:
        print("Folder redirection: skipped")
        return

    home = Path.home()
    cloud_root = find_cloud_root(provider, home)
    if cloud_root is None:
        # Moving files into a folder the sync app isn't watching would just strand them
        # locally under a misleading name, so don't create one - wait for the real thing.
        print(f"Folder redirection: {provider}'s sync folder wasn't found - install {provider}, sign "
              f"in and let it finish setting up, then re-run with --cloudstorage '{provider}'")
        return

    print(f"Folder redirection: {provider} at {cloud_root}")
    for name, cloud_relative_path in REDIRECTIONS.items():
        redirect_folder(name, cloud_relative_path, home, cloud_root)


def restart_apps(apps):
    for app in apps:
        subprocess.run(
            ["killall", app], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="First-run Mac preference tweaks, plus optional "
                                                 "redirection of Desktop/Documents/Downloads into cloud storage. "
                                                 "Run with no options to show this help.")
    parser.add_argument("--run", "--Run", action="store_true",
                        help="Apply the settings, asking about cloud storage unless --cloudstorage is given.")
    parser.add_argument("--cloudstorage", "--cloud-storage", metavar="NAME", type=parse_cloud_provider,
                        default=argparse.SUPPRESS,
                        help="Move Desktop/Documents/Downloads into this provider's sync folder: "
                             "'OneDrive', 'Proton Drive', 'iCloud Drive', or 'None' to skip. "
                             "If omitted, you're asked.")
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)
    args = parser.parse_args()
    # Asked up front, before the sudo prompt and the slower steps, so the rest runs unattended.
    cloud_provider = args.cloudstorage if "cloudstorage" in args else prompt_for_provider()

    start_sudo_keepalive()
    configure_startup_chime()
    configure_dock()
    configure_finder()
    reset_finder_view_settings()
    configure_desktop()
    configure_window_corners()
    configure_menu_bar()
    configure_time_format()
    configure_textedit()
    configure_music()
    configure_mail()
    configure_misc()
    configure_trackpad()
    configure_software_update()
    configure_printing()
    configure_multi_app_settings()
    configure_firewall()
    configure_login_window()
    configure_terminal()
    configure_folder_redirection(cloud_provider)
    # Restarting Finder last also makes it pick up the redirected Desktop/Documents/Downloads.
    restart_apps(RESTART_APPS)
