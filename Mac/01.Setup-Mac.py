#!/usr/bin/env python3
import argparse
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from dataclasses import dataclass
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


DEFAULT_NAME_PATTERN = re.compile(
    r".+[’']s (MacBook( Air| Pro)?|iMac|Mac mini|Mac Pro|Mac Studio|Mac)$", re.IGNORECASE
)

BREW_INSTALL_SCRIPT_URL = "https://raw.githubusercontent.com/Homebrew/install/master/install.sh"

BREW_PATHS = (Path("/opt/homebrew/bin/brew"), Path("/usr/local/bin/brew"))


@dataclass(frozen=True)
class App:
    name: str
    kind: str  # "formula", "cask" or "mas" (Mac App Store, by numeric ID)
    id: str


# Same categories and order as Setup-Windows.ps1, so an app lives in the same menu on
# every platform. Pick apps per category when the script starts.
CATEGORIES = [
    ("Comms", [
        App("Discord", "cask", "discord"),
        App("Slack", "cask", "slack"),
        App("Signal", "cask", "signal"),
        App("Microsoft Teams", "cask", "microsoft-teams"),
    ]),
    ("Media", [
        App("Spotify", "cask", "spotify"),
        App("foobar2000", "cask", "foobar2000"),
        App("VLC", "cask", "vlc"),
        App("Jellyfin Media Player", "cask", "jellyfin-media-player"),
        App("yt-dlp", "formula", "yt-dlp"),
    ]),
    ("Office Apps", [
        App("Microsoft 365 (Office)", "cask", "microsoft-office"),
        App("Microsoft AutoUpdate", "cask", "microsoft-auto-update"),
        App("Microsoft To Do", "mas", "1274495053"),
        App("Obsidian", "cask", "obsidian"),
    ]),
    ("Utilities", [
        App("Fastfetch", "formula", "fastfetch"),
        App("Bitwarden", "cask", "bitwarden"),
        App("Bitwarden CLI", "formula", "bitwarden-cli"),
        App("Wireshark", "cask", "wireshark-app"),  # plain "wireshark" is the CLI-only formula
        App("Windows App", "mas", "1295203466"),
        App("OneDrive", "cask", "onedrive"),  # needed by 02.Configure-Mac.py --cloudstorage OneDrive
        App("Microsoft Edge", "cask", "microsoft-edge"),
        App("balenaEtcher", "cask", "balenaetcher"),
        App("Raspberry Pi Imager", "cask", "raspberry-pi-imager"),
        App("Intune Company Portal", "cask", "intune-company-portal"),
        App("AltTab", "cask", "alt-tab"),
        App("Scroll Reverser", "cask", "scroll-reverser"),
        App("Vorssaint (menu bar keep-awake/monitor/mixer)", "cask", "vorssaint"),
        App("New File Menu", "mas", "1064959555"),
        App("Smartcard Utility", "mas", "1444710309"),
        App("Controller for HomeKit", "mas", "1198176727"),
    ]),
    ("Dev", [
        App("PowerShell", "formula", "powershell"),
        App("Azure CLI", "formula", "azure-cli"),
        App("Visual Studio Code", "cask", "visual-studio-code"),
        App(".NET Runtime", "cask", "dotnet"),
        App("AzCopy", "formula", "azcopy"),
        App("Azure Storage Explorer", "cask", "microsoft-azure-storage-explorer"),
        App("Royal TSX", "cask", "royal-tsx"),
    ]),
    ("Creative", [
        App("Adobe Acrobat Reader", "cask", "adobe-acrobat-reader"),
        App("Affinity", "cask", "affinity"),
        App("draw.io", "cask", "drawio"),
    ]),
    ("Others", [
        App("Steam", "cask", "steam"),
        App("Bambu Studio", "cask", "bambu-studio"),
        App("GeForce NOW", "cask", "nvidia-geforce-now"),
    ]),
    ("AI", [
        App("Claude", "cask", "claude"),
        App("Claude Code", "cask", "claude-code"),
        App("ChatGPT", "cask", "chatgpt"),
    ]),
    # Mac-only: modern CLI replacements picked up by ~/.bash_aliases/unix.sh. Each alias
    # there only turns on when its tool is installed, so skipping any of these is safe.
    ("CLI Tools", [
        App("eza (ls)", "formula", "eza"),
        App("bat (cat)", "formula", "bat"),
        App("btop (top)", "formula", "btop"),
        App("fd (find)", "formula", "fd"),
        App("dust (du)", "formula", "dust"),
        App("procs (ps)", "formula", "procs"),
        App("gping (ping)", "formula", "gping"),
        App("delta (diff pager)", "formula", "git-delta"),
    ]),
]

# Cricut Design Space isn't in Homebrew - install it from cricut.com/setup.


class SelectionCancelled(Exception):
    pass


def show_category_menu(category, apps):
    """Same menu as Setup-Windows.ps1: A = all, S or blank = skip, Q = quit, or a list like 1,3."""
    print()
    print(f"=== {category} ===")
    print("Select apps to install for this category.")
    print("  A = all apps")
    print("  S = skip this category")
    print("  Q = quit")
    for index, app in enumerate(apps, start=1):
        print(f"  {index}. {app.name} ({app.id})")

    selection = input("Enter selection (for example: 1,3 or A): ").strip().lower()
    if selection in ("", "s", "skip"):
        return []
    if selection in ("a", "all"):
        return list(apps)
    if selection in ("q", "quit"):
        raise SelectionCancelled

    selected = []
    for token in selection.split(","):
        token = token.strip()
        if not token:
            continue
        if token.isdigit() and 1 <= int(token) <= len(apps):
            selected.append(apps[int(token) - 1])
        else:
            print(f"Warning: ignoring invalid selection '{token}'.")
    return selected


def choose_apps(install_all=False):
    if install_all:
        print("--install-all: installing every app in every category, no menus.")
        return {name: list(apps) for name, apps in CATEGORIES}
    try:
        return {name: show_category_menu(name, apps) for name, apps in CATEGORIES}
    except SelectionCancelled:
        sys.exit("Selection cancelled. Exiting.")


def host_name_slug(name):
    """HostName/LocalHostName only allow letters, digits and hyphens - "Tim's MacBook Pro"
    becomes "tims-macbook-pro". The friendly ComputerName keeps whatever was typed."""
    return re.sub(r"[^a-z0-9]+", "-", name.lower().replace("'", "").replace("\u2019", "")).strip("-")[:63]


def set_computer_name(requested=None):
    result = subprocess.run(["scutil", "--get", "ComputerName"], capture_output=True, text=True)
    current = result.stdout.strip() if result.returncode == 0 else ""

    if requested:
        # Passed explicitly with --machine-name, so apply it even if the Mac was renamed before.
        compname = requested.strip()
    else:
        if current and not DEFAULT_NAME_PATTERN.match(current):
            print(f"Computer name already set to '{current}', skipping")
            return
        compname = input(f"Enter machine name [{current}]: ").strip() or current

    if not compname:
        print("Machine name can't be empty, skipping")
        return
    if compname == current:
        print(f"Keeping computer name '{current}'")
        return
    slug = host_name_slug(compname)
    if not slug:
        print(f"'{compname}' has no letters or digits to build a host name from, skipping")
        return

    run(["sudo", "scutil", "--set", "ComputerName", compname])
    run(["sudo", "scutil", "--set", "HostName", slug])
    run(["sudo", "scutil", "--set", "LocalHostName", slug])
    print(f"Computer name set to '{compname}' (network name '{slug}')")


def install_xcode_clt():
    result = subprocess.run(["xcode-select", "-p"], capture_output=True)
    if result.returncode == 0:
        print("Xcode Command Line Tools already installed, skipping")
        return

    print("Installing Xcode Command Line Tools - a system dialog will pop up, click through it.")
    # Not check=True: --install's exit status is unreliable across macOS versions even when
    # it successfully triggers the dialog, so treating a nonzero code here as fatal would
    # kill the script right after the dialog opens, before the install ever finishes.
    subprocess.run(["xcode-select", "--install"])

    print("Waiting for the install to finish (this can take several minutes)...")
    elapsed = 0
    while subprocess.run(["xcode-select", "-p"], capture_output=True).returncode != 0:
        time.sleep(5)
        elapsed += 5
        if elapsed % 60 == 0:
            print(f"  ... still waiting ({elapsed // 60} min)")
    print("Xcode Command Line Tools installed.")


def find_brew():
    for path in BREW_PATHS:
        if path.exists():
            return path
    on_path = shutil.which("brew")
    return Path(on_path) if on_path else None


def ensure_brew_on_path(brew):
    # Deliberately not parsed from 'brew shellenv' output: on macOS 14+ it emits an
    # 'eval "$(path_helper ...)"' call instead of a plain 'export PATH=', and even on
    # older macOS the PATH line contains unexpanded shell syntax ('${PATH+:$PATH}') -
    # both are meant for a shell's eval, not for a script to parse. We already know
    # brew's own bin/sbin dirs, so just prepend them directly.
    bin_dir = str(brew.parent)
    sbin_dir = str(brew.parent.parent / "sbin")
    path_dirs = os.environ.get("PATH", "").split(":") if os.environ.get("PATH") else []
    for d in (sbin_dir, bin_dir):
        if d not in path_dirs:
            path_dirs.insert(0, d)
    os.environ["PATH"] = ":".join(path_dirs)

    zprofile = Path.home() / ".zprofile"
    shellenv_line = f'eval "$({brew} shellenv)"'
    if not zprofile.exists() or shellenv_line not in zprofile.read_text():
        with zprofile.open("a") as f:
            f.write(f"{shellenv_line}\n")


def run(cmd):
    """Run a command; warn and continue on failure instead of aborting the whole script."""
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print(f"Warning: {' '.join(cmd)} exited with status {result.returncode}")
    return result.returncode == 0


def install_homebrew():
    brew = find_brew()
    if brew:
        print("Homebrew already installed, skipping install")
        ensure_brew_on_path(brew)
        return

    print("Installing Homebrew...")
    with urllib.request.urlopen(BREW_INSTALL_SCRIPT_URL) as response:
        install_script = response.read().decode()
    subprocess.run(["/bin/bash", "-c", install_script], check=True)

    brew = find_brew()
    if not brew:
        raise RuntimeError("Homebrew install finished but brew was not found")
    ensure_brew_on_path(brew)

    run(["brew", "update"])
    run(["brew", "upgrade"])


def install_app(app):
    if app.kind == "formula":
        return run(["brew", "install", app.id])
    if app.kind == "cask":
        return run(["brew", "install", "--cask", app.id])
    if not shutil.which("mas"):
        print(f"mas not available, can't install {app.name}")
        return False
    return run(["mas", "install", app.id])


def install_selected(selected_by_category):
    # mas is only a prerequisite for App Store picks, so it's installed only when needed.
    if any(app.kind == "mas" for apps in selected_by_category.values() for app in apps):
        run(["brew", "install", "mas"])

    failed = []
    for category, apps in selected_by_category.items():
        if not apps:
            print(f"Skipping {category}.")
            continue
        print(f"\nInstalling apps for {category}...")
        for app in apps:
            print(f"Installing {app.name}...")
            if not install_app(app):
                failed.append(app.name)

    if failed:
        print(f"\n{len(failed)} app(s) failed to install - review the output above and retry manually if needed:")
        for name in failed:
            print(f"  - {name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="First-run Mac setup: computer name, Xcode Command "
                                                 "Line Tools, Homebrew, then apps picked from a menu per category. "
                                                 "Run with no options to show this help.")
    parser.add_argument("--run", "--Run", action="store_true",
                        help="Run setup, asking for anything not given on the command line.")
    parser.add_argument("--machine-name", "--Machine-Name", metavar="NAME", dest="machine_name",
                        help="Computer name to set. If omitted, you're asked - but only while the Mac "
                             "still has its default name.")
    parser.add_argument("--install-all", "--Install-All", action="store_true", dest="install_all",
                        help="Skip the app menus and install every app in every category.")
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)
    args = parser.parse_args()

    start_sudo_keepalive()
    set_computer_name(args.machine_name)
    # Ask everything up front so the long installs below can run unattended.
    selected = choose_apps(args.install_all)
    install_xcode_clt()
    install_homebrew()
    install_selected(selected)
