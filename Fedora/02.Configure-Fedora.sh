#!/usr/bin/env bash

# Script Name: 02.Configure-Fedora.sh
# Description: First-run preference tweaks for Fedora Workstation (GNOME) - the
#              counterpart to 02.Configure-Mac.py and 02.Configure-Windows.ps1.
# Author: Tsull
# Usage: ./02.Configure-Fedora.sh --run   (no options shows help; run after 01.Setup-Fedora.sh, as your normal
#        user, from a terminal inside your GNOME session - it sudos internally
#        for the one system-wide step)
# Notes: Safe to re-run - every step just re-applies the same setting.

set -uo pipefail

log() { echo "[$1] $2"; }

print_usage() {
    echo "Usage: ./02.Configure-Fedora.sh --run"
    echo "  Applies GNOME preferences (window buttons, 24-hour clock, Ptyxis opacity),"
    echo "  stops GNOME Software autostarting, and enables AirPlay speaker discovery."
    echo "  Run as your normal user from a terminal inside your GNOME session."
    echo "  --run       Apply the settings."
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

#region Setup / safety
if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not as root/sudo directly." >&2
    echo "These are per-user GNOME/PipeWire settings - running as root would" >&2
    echo "apply them to root's profile instead of yours." >&2
    exit 1
fi

# gsettings and the PipeWire user services need the desktop session's D-Bus.
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -z "${XDG_CURRENT_DESKTOP:-}" ]]; then
    echo "No desktop session detected in this shell. Run this from a terminal" >&2
    echo "inside your GNOME session." >&2
    exit 1
fi
#endregion

#region GNOME preferences
gsettings set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"
log "Windows" "Minimize/maximize/close buttons shown"

# 24-hour time for the top bar clock, and for GTK file choosers (they have
# their own setting, separate from the shell's).
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gtk.Settings.FileChooser clock-format '24h' 2>/dev/null || true
gsettings set org.gtk.gtk4.Settings.FileChooser clock-format '24h' 2>/dev/null || true
log "Clock" "24-hour time enabled"

if gsettings list-schemas | grep -q '^org.gnome.Ptyxis$'; then
    ptyxis_profile=$(gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null | tr -d "'")
    if [[ -n "$ptyxis_profile" ]]; then
        gsettings set "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$ptyxis_profile/" opacity 0.90
        log "Ptyxis" "Opacity set to 0.90 on default profile ($ptyxis_profile)"
    else
        log "Ptyxis" "Could not determine default profile UUID - skipped opacity tweak"
    fi
fi
#endregion

#region GNOME Software autostart
# Stops GNOME Software from starting in the background at every login to check
# for updates (04.Update-Fedora.sh handles updates instead). System-wide file,
# hence sudo.
if [[ -f /etc/xdg/autostart/org.gnome.Software.desktop ]]; then
    sudo rm -f /etc/xdg/autostart/org.gnome.Software.desktop
    log "GNOME Software" "Background autostart at login disabled"
else
    log "GNOME Software" "Autostart already disabled"
fi
#endregion

#region AirPlay speaker discovery (PipeWire RAOP)
# Makes AirPlay speakers on the network show up as audio outputs. Configured
# permanently, rather than with a one-off 'pactl load-module' that's lost at the
# next reboot or audio restart.
#
# Fedora 43+ ships this as the pipewire-config-raop package (a system-wide
# drop-in). On older releases that package doesn't exist, so the same setting
# goes in a per-user drop-in instead. Only one of the two is used - loading the
# module twice would list every speaker twice.
raop_system_conf="/usr/share/pipewire/pipewire.conf.d/50-raop.conf"
raop_user_conf="$HOME/.config/pipewire/pipewire.conf.d/50-raop-discover.conf"

if [[ ! -f "$raop_system_conf" ]]; then
    sudo dnf install -y pipewire-config-raop >/dev/null 2>&1
fi

if [[ -f "$raop_system_conf" ]]; then
    # The package covers it - drop the per-user copy from an earlier run, if any.
    rm -f "$raop_user_conf"
    log "AirPlay" "Discovery enabled via the pipewire-config-raop package"
else
    mkdir -p "$(dirname "$raop_user_conf")"
    cat > "$raop_user_conf" <<'EOF'
# Managed by 02.Configure-Fedora.sh - discovers AirPlay (RAOP) speakers on the network.
context.modules = [
    {   name = libpipewire-module-raop-discover
        args = { }
    }
]
EOF
    log "AirPlay" "Discovery enabled via $raop_user_conf"
fi

# Restart the audio services so it takes effect now (audio drops for a second).
systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null \
    && log "AirPlay" "Audio services restarted - AirPlay speakers should now appear in Sound settings" \
    || log "AirPlay" "Couldn't restart audio services - takes effect at next login"
#endregion

echo
log "Done" "Configuration complete."
echo "Log out and back in (or reboot) so the button layout and clock changes apply everywhere."
