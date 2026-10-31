#!/bin/bash

# Script Name: Update-Fedora.sh
# Description: Updates packages and firmware for Fedora, then reboots if needed
# Author: Tsull
# Date: 04-11-2025
# Version: 1.1 (fixed the unclosed if/else and inverted needs-restarting check -
#          the same two bugs 01.Setup-Fedora.sh's changelog already documents
#          and fixed for its own reboot check)
# Usage: ./04.Update-Fedora.sh --run   (no options shows help)
# Notes: Always seeking to improve.

print_usage() {
    echo "Usage: ./04.Update-Fedora.sh --run"
    echo "  Updates dnf packages, Flatpak apps and firmware (fwupdmgr), cleans the"
    echo "  package cache, removes orphaned packages, then reboots if one is needed."
    echo "  --run       Run the updates."
    echo "  -h, --help  Show this help. Running with no options also shows it."
}

RUN=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --run|--Run) RUN=1 ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo "Unknown option: $1 (run with --help)" >&2; exit 1 ;;
    esac
    shift
done
if [[ $RUN -eq 0 ]]; then
    print_usage
    exit 0
fi

# Update everything
sudo dnf update -y

# Flatpak apps (most desktop apps from 01.Setup-Fedora.sh live here, not in dnf)
command -v flatpak >/dev/null 2>&1 && flatpak update -y --noninteractive

# See what can be updated
sudo fwupdmgr get-devices

# Refresh the firmware database
sudo fwupdmgr refresh --force

# Check for updates
sudo fwupdmgr get-updates

# Apply them
sudo fwupdmgr update

# Clean package cache
sudo dnf clean all

# Remove orphaned packages
sudo dnf autoremove -y

# needs-restarting (from dnf-utils) isn't installed on a stock Fedora Workstation
# image - without it, the check below fails with "command not found" (exit 127),
# which is indistinguishable from "reboot needed" (exit 1).
command -v needs-restarting >/dev/null 2>&1 || sudo dnf install -y dnf-utils

# needs-restarting -r exit codes are the opposite of what you'd guess:
# 0 = reboot NOT needed, 1 = reboot IS needed.
if needs-restarting -r >/dev/null 2>&1; then
    echo "No reboot needed."
else
    echo "Reboot required. Rebooting now..."
    sudo reboot
fi

