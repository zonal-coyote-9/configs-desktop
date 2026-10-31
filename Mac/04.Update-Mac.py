#!/usr/bin/env python3
import argparse
import shutil
import subprocess
import sys
import threading
import time

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


# None of these steps should abort the run if one fails (e.g. mas not signed
# in, or a single formula failing to build) - each is independent, so we
# just report and move on to the next one.


def run(cmd):
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print(f"Warning: {' '.join(cmd)} exited with status {result.returncode}")


def update_homebrew():
    run(["brew", "update"])
    run(["brew", "upgrade"])
    run(["brew", "cleanup", "-s"])
    run(["brew", "upgrade", "--cask"])
    run(["brew", "doctor"])
    run(["brew", "missing"])


def update_mas_apps():
    if not shutil.which("mas"):
        print("mas not installed, skipping App Store updates")
        return
    run(["mas", "outdated"])
    run(["mas", "upgrade"])


def update_macos():
    run(["sudo", "softwareupdate", "--all", "--install", "--force", "-R"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Recurring maintenance: Homebrew formula/cask upgrades, "
                                                 "Mac App Store updates (mas) and macOS software updates. "
                                                 "Run with no options to show this help.")
    parser.add_argument("--run", "--Run", action="store_true", help="Run the updates.")
    args = parser.parse_args()
    if not args.run:
        parser.print_help()
        sys.exit(0)

    # Cask upgrades that ship .pkg installers and softwareupdate both need sudo.
    start_sudo_keepalive()
    update_homebrew()
    update_mas_apps()
    update_macos()
