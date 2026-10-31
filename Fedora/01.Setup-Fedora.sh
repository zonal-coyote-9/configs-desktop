#!/usr/bin/env bash

# Script Name: Setup-Fedora.sh
# Description: Installs apps and settings for Fedora Workstation (GNOME)
# Author: Tsull
# Date: 04-11-2025
# Version: 1.1 (fixed several bugs from 1.0 - see CHANGELOG below)
# Usage: ./01.Setup-Fedora.sh --run | --machine-name NAME | --install-all
#        (run as your normal user - it sudos internally; no options shows help)
#        --run                run setup, asking for anything not given on the command line
#        --machine-name NAME  hostname to set (asked for if omitted)
#        --install-all        skip the app menus and install every app in every category
# Notes: Always seeking to improve. Safe to re-run - every step checks
#        whether it already applied before doing anything.
#
# CHANGELOG (1.0 -> 1.1):
#   - The reboot-check if/else was never closed with `fi`, so the entire
#     rest of the script (everything past the reboot check) lived inside
#     the else branch and the file didn't parse at all (bash refused to
#     run any of it: "syntax error: unexpected end of file").
#   - `needs-restarting -r` exit codes are inverted from what the old
#     if/else assumed: it exits 0 when NO reboot is needed and 1 when one
#     IS needed. The old logic had "reboot now" and "no reboot needed"
#     backwards.
#   - `dnf group upgrade core -y` only upgrades the "core" package group,
#     not the whole system, despite the comment saying "update everything".
#     Changed to `dnf upgrade --refresh -y`.
#   - Most `flatpak install` calls were missing `-y` and/or the `flathub`
#     remote name, so they'd sit waiting for interactive confirmation on a
#     "non-interactive" setup script. Consolidated into one batched,
#     non-interactive install.
#   - `$PTYXIS_PROFILE` was referenced but never set anywhere, so the
#     opacity tweak always failed. Now discovered via gsettings.
#   - `gnome-extensions-cli install 307` duplicated the line above it (307
#     IS Dash to Dock's extensions.gnome.org ID) - installed the same
#     extension twice. Removed the duplicate.
#   - `pip3 install gnome-extensions-cli` fails on current Fedora
#     ("externally-managed-environment"). Switched to pipx, the method the
#     project itself recommends.
#   - Added idempotency checks throughout (repo/font/package "already
#     present" guards, `pactl` module check, `rm -f`) and a single sudo
#     keep-alive so you're not prompted for your password a dozen times.
#   - Added a guard so this refuses to run as root/sudo directly, since
#     several steps (gsettings, flatpak, pipx) are meant to run as your
#     normal user and would otherwise land in root's profile instead.

set -uo pipefail

log() { echo "[$1] $2"; }

print_usage() {
    echo "Usage: ./01.Setup-Fedora.sh --run | --machine-name NAME | --install-all"
    echo "  --run                Run setup, asking for anything not given on the command line."
    echo "  --machine-name NAME  Hostname to set. Asked for if omitted."
    echo "  --install-all        Skip the app menus and install every app in every category."
    echo "  -h, --help           Show this help. Running with no options also shows it."
}

if [[ $# -eq 0 ]]; then
    print_usage
    exit 0
fi

INSTALL_ALL=0
MACHINE_NAME=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --run|--Run) ;;
        --install-all|--Install-All) INSTALL_ALL=1 ;;
        --machine-name|--Machine-Name)
            if [[ -z "${2:-}" ]]; then
                echo "$1 needs a value, e.g. $1 my-laptop" >&2
                exit 1
            fi
            MACHINE_NAME="$2"; shift ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo "Unknown option: $1 (run with --help)" >&2; exit 1 ;;
    esac
    shift
done

#region Setup / safety
if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not as root/sudo directly." >&2
    echo "It calls sudo itself for the specific steps that need it -" >&2
    echo "running the whole script as root would install GNOME/flatpak/pipx" >&2
    echo "settings into root's profile instead of yours." >&2
    exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
    echo "dnf not found - this script is written for Fedora." >&2
    exit 1
fi

# One password prompt up front, then keep sudo alive in the background for
# the rest of the run instead of prompting repeatedly.
sudo -v
(
    while true; do
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
        sudo -n true 2>/dev/null
    done
) &
SUDO_KEEPALIVE_PID=$!
trap '[[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# Does this session have a running GNOME desktop (needed for
# gnome-extensions-cli later)? Falls back gracefully if run headlessly.
HAVE_DESKTOP_SESSION=0
if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" || -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
    HAVE_DESKTOP_SESSION=1
fi
#endregion

#region Hostname
machname="$MACHINE_NAME"
[[ -z "$machname" ]] && read -rp "Enter machine name: " machname
# The static hostname has stricter rules than the pretty one (no spaces,
# apostrophes, etc.), so derive a safe slug from whatever was typed instead
# of feeding the raw string to both.
make_static_name() { echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d "'" | tr -cs 'a-z0-9' '-' | sed -E 's/^-+//; s/-+$//'; }
static_name=$(make_static_name "$machname")
while [[ -z "$static_name" ]]; do
    read -rp "Machine name needs at least one letter or digit - enter machine name: " machname
    static_name=$(make_static_name "$machname")
done
sudo hostnamectl set-hostname --pretty "$machname"
sudo hostnamectl set-hostname --static "$static_name"
log "Hostname" "Pretty='$machname' Static='$static_name'"
#endregion

#region Repo setup + system upgrade
log "Repos" "Adding RPM Fusion free/nonfree if not already present..."
rpm -q rpmfusion-free-release >/dev/null 2>&1 || \
    sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
rpm -q rpmfusion-nonfree-release >/dev/null 2>&1 || \
    sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

log "Update" "Upgrading the whole system (dnf upgrade --refresh)..."
sudo dnf upgrade --refresh -y

# needs-restarting (from dnf-utils) isn't installed on a stock Fedora
# Workstation image. Without this, the command below fails with "command
# not found" (exit 127), which the reboot check below can't distinguish
# from "reboot needed" (exit 1) - so it would reboot on every single run,
# every time, before ever reaching the app installs.
command -v needs-restarting >/dev/null 2>&1 || sudo dnf install -y dnf-utils

# needs-restarting -r exit codes are the opposite of what you'd guess:
#   0 = reboot NOT needed, 1 = reboot IS needed.
if needs-restarting -r >/dev/null 2>&1; then
    log "Reboot" "Not needed - continuing."
else
    log "Reboot" "Required (kernel/core packages were updated)."
    echo "Rebooting in 10 seconds - Ctrl+C to cancel."
    echo "Re-run this script after rebooting to continue with app installs (every step above is safe to skip on the next run)."
    sleep 10
    sudo reboot
    exit 0
fi
#endregion

#region App selection
# Same categories, menu and keys as Setup-Windows.ps1 (and 01.Setup-Mac.py), so an
# app lives in the same menu on every platform. Asked here - after the reboot
# check above - so a fresh install that reboots mid-setup only asks once, and
# everything after this runs unattended.
#
# Each entry is "Name|kind|id", where kind is:
#   flatpak - installed from Flathub
#   dnf     - installed from the Fedora/RPM Fusion repos
#   vscode  - Microsoft's own VS Code repo (added on demand)
#   claudecode - Anthropic's official Claude Code installer (installs to ~/.local)
#   weblink - an app-grid launcher that opens the given URL in your browser, for
#             services with no official Linux desktop app
cat_comms=(
    "Discord|flatpak|com.discordapp.Discord"
    "Slack|flatpak|com.slack.Slack"
    "Signal|flatpak|org.signal.Signal"
    "BlueBubbles|flatpak|app.bluebubbles.BlueBubbles"
)
cat_media=(
    "Spotify|flatpak|com.spotify.Client"
    "VLC|flatpak|org.videolan.VLC"
    "Jellyfin Media Player|flatpak|com.github.iwalton3.jellyfin-media-player"
    "yt-dlp|dnf|yt-dlp"
)
cat_office=(
    "ONLYOFFICE|flatpak|org.onlyoffice.desktopeditors"
    "Evolution (mail/calendar)|flatpak|org.gnome.Evolution"
    "Obsidian|flatpak|md.obsidian.Obsidian"
)
cat_utilities=(
    "Fastfetch|dnf|fastfetch"
    "Bitwarden|flatpak|com.bitwarden.desktop"
    "Wireshark|dnf|wireshark"
    "Remmina (RDP client - counterpart to Windows App)|flatpak|org.remmina.Remmina"
    "Raspberry Pi Imager|flatpak|org.raspberrypi.rpi-imager"
    "Mission Center|flatpak|io.missioncenter.MissionCenter"
    "Gear Lever (AppImages)|flatpak|it.mijorus.gearlever"
    "Extension Manager|flatpak|com.mattjakeman.ExtensionManager"
)
cat_dev=(
    "Visual Studio Code|vscode|code"
    "Azure CLI|dnf|azure-cli"
)
# NOTE: com.adobe.Reader wraps Adobe's own Linux binary, which Adobe abandoned
# around 2013 (last release 9.5.5) - the Flathub packaging is current, but the
# app itself hasn't been patched in over a decade. Consider Papers/Evince
# (already installed with GNOME) if that matters to you.
cat_creative=(
    "Adobe Acrobat Reader|flatpak|com.adobe.Reader"
    "draw.io|flatpak|com.jgraph.drawio.desktop"
)
# Neither Claude nor ChatGPT has an official Linux desktop app (Flathub only has
# third-party wrappers, which you'd be signing your accounts into), so those two
# are launchers for the official web apps instead. Claude Code is the real CLI.
cat_ai=(
    "Claude (web app launcher)|weblink|https://claude.ai"
    "Claude Code|claudecode|claude"
    "ChatGPT (web app launcher)|weblink|https://chatgpt.com"
)
cat_others=(
    "Steam|flatpak|com.valvesoftware.Steam"
    "Bambu Studio|flatpak|com.bambulab.BambuStudio"
)
category_names=("Comms" "Media" "Office Apps" "Utilities" "Dev" "Creative" "Others" "AI")
category_arrays=(cat_comms cat_media cat_office cat_utilities cat_dev cat_creative cat_others cat_ai)

selected_apps=()

# Appends the chosen entries of the array named $2 to selected_apps.
# Returns 1 if the user chose to quit.
show_category_menu() {
    local category="$1"
    local -n apps="$2"
    local i selection token name id
    local -a tokens

    echo
    echo "=== $category ==="
    echo "Select apps to install for this category."
    echo "  A = all apps"
    echo "  S = skip this category"
    echo "  Q = quit"
    for i in "${!apps[@]}"; do
        IFS='|' read -r name _ id <<< "${apps[$i]}"
        echo "  $((i + 1)). $name ($id)"
    done

    read -rp "Enter selection (for example: 1,3 or A): " selection
    selection=$(echo "$selection" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    case "$selection" in
        ""|s|skip) return 0 ;;
        a|all) selected_apps+=("${apps[@]}"); return 0 ;;
        q|quit) return 1 ;;
    esac

    IFS=',' read -ra tokens <<< "$selection"
    for token in "${tokens[@]}"; do
        [[ -z "$token" ]] && continue
        if [[ "$token" =~ ^[0-9]+$ ]] && (( 10#$token >= 1 && 10#$token <= ${#apps[@]} )); then
            selected_apps+=("${apps[$((10#$token - 1))]}")
        else
            echo "Warning: ignoring invalid selection '$token'." >&2
        fi
    done
}

# Appends every entry of the array named $1 to selected_apps (for --install-all).
select_all_apps() {
    local -n apps="$1"
    selected_apps+=("${apps[@]}")
}

[[ $INSTALL_ALL -eq 1 ]] && log "Apps" "--install-all: installing every app in every category, no menus"
for i in "${!category_names[@]}"; do
    if [[ $INSTALL_ALL -eq 1 ]]; then
        select_all_apps "${category_arrays[$i]}"
    elif ! show_category_menu "${category_names[$i]}" "${category_arrays[$i]}"; then
        echo "Selection cancelled. Exiting."
        exit 1
    fi
done

selected_flatpaks=()
selected_dnf=()
want_vscode=0
want_claude_code=0
selected_weblinks=()
for entry in "${selected_apps[@]}"; do
    IFS='|' read -r _ kind id <<< "$entry"
    case "$kind" in
        flatpak) selected_flatpaks+=("$id") ;;
        dnf) selected_dnf+=("$id") ;;
        vscode) want_vscode=1 ;;
        claudecode) want_claude_code=1 ;;
        weblink) selected_weblinks+=("$entry") ;;
    esac
done
#endregion

#region Flatpak setup + apps
log "Flatpak" "Switching from the limited Fedora remote to Flathub..."
flatpak remote-list | grep -q '^fedora' && flatpak remote-delete fedora
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

if [[ ${#selected_flatpaks[@]} -gt 0 ]]; then
    flatpak install -y --noninteractive flathub "${selected_flatpaks[@]}"
else
    log "Flatpak" "No Flatpak apps selected"
fi
#endregion

#region CLI tools / archive support (always installed) + selected dnf apps
sudo dnf install -y git p7zip p7zip-plugins unrar
[[ ${#selected_dnf[@]} -gt 0 ]] && sudo dnf install -y "${selected_dnf[@]}"

# Packet capture as a normal user needs the wireshark group (takes effect after
# logging out and back in).
if [[ " ${selected_dnf[*]} " == *" wireshark "* ]] && ! id -nG "$USER" | grep -qw wireshark; then
    sudo usermod -aG wireshark "$USER"
    log "Wireshark" "Added $USER to the wireshark group"
fi
#endregion

#region AI apps (only if selected)
if [[ $want_claude_code -eq 1 ]]; then
    if command -v claude >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/claude" ]]; then
        log "Claude Code" "Already installed"
    else
        # Anthropic's official installer - runs as you (not sudo) and installs
        # under ~/.local, same as the claude-code cask / winget package elsewhere.
        curl -fsSL https://claude.ai/install.sh | bash
    fi
fi

for entry in "${selected_weblinks[@]}"; do
    IFS='|' read -r name _ url <<< "$entry"
    app_name="${name%% (*}"   # "Claude (web app launcher)" -> "Claude"
    slug=$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -E 's/^-+//; s/-+$//')
    desktop_file="$HOME/.local/share/applications/$slug-web.desktop"
    mkdir -p "$(dirname "$desktop_file")"
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=$app_name
Comment=Opens $url in your web browser
Exec=xdg-open $url
Icon=web-browser
Categories=Network;
EOF
    log "$app_name" "Launcher added to the app grid (opens $url)"
done
#endregion

#region VS Code (Microsoft repo, only if selected)
if [[ $want_vscode -eq 1 ]] && ! rpm -q code >/dev/null 2>&1; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    sudo dnf install -y code
fi
#endregion

#region Fonts
sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig

# --nodigest --nosignature is required here because this particular rpm is
# unsigned (it's a self-extracting installer, not a normal RPM Fusion/Fedora
# package) - that's expected for this specific package, not a shortcut.
if ! rpm -q msttcore-fonts-installer >/dev/null 2>&1; then
    sudo rpm -i --nodigest --nosignature \
        https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
    sudo fc-cache -f
fi
#endregion

#region AppImage support (FUSE - used by Gear Lever and AppImages in general)
sudo dnf install -y fuse fuse-libs
#endregion

#region AMD drivers + hardware video acceleration
sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
sudo dnf install -y mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld
#endregion

#region Codecs
# Replace the neutered ffmpeg with the full RPM Fusion build.
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf install -y ffmpeg-libs libva libva-utils

# Quoting the globs (instead of the old backslash-escaped brace expansion)
# so dnf gets the literal wildcard pattern without relying on bash not
# matching a local file by coincidence.
sudo dnf install -y \
    "gstreamer1-plugins-bad-*" \
    "gstreamer1-plugins-good-*" \
    gstreamer1-plugins-base \
    gstreamer1-plugin-openh264 \
    gstreamer1-libav \
    "lame*" \
    --exclude=gstreamer1-plugins-bad-free-devel

# On dnf5, "group install" can report "no package changes" if the group's
# packages are already present from the steps above - that's fine, it just
# means there's nothing left to do.
sudo dnf group install -y multimedia
sudo dnf group install -y sound-and-video
#endregion

#region GNOME Tweaks + extensions
# Preferences (button layout, clock, terminal, AirPlay, GNOME Software autostart)
# live in 02.Configure-Fedora.sh - this region only installs things.
if [[ $HAVE_DESKTOP_SESSION -eq 1 ]]; then
    sudo dnf install -y gnome-tweaks

    # gnome-extensions-cli install (pip) fails on modern Fedora with
    # "externally-managed-environment" - pipx (with access to the
    # system PyGObject/dbus bindings it needs) is what the project itself
    # recommends instead.
    sudo dnf install -y pipx python3-gobject python3-dbus
    export PATH="$HOME/.local/bin:$PATH"
    if ! pipx list 2>/dev/null | grep -q gnome-extensions-cli; then
        pipx install --system-site-packages gnome-extensions-cli
    fi

    if command -v gnome-extensions-cli >/dev/null 2>&1; then
        # 307 is Dash to Dock's own extensions.gnome.org ID - installing it
        # by number as well as by UUID would just reinstall the same
        # extension a second time, so only one form is kept.
        gnome-extensions-cli install background-logo@fedorahosted.org || true
        gnome-extensions-cli install Bluetooth-Battery-Meter@maniacx.github.com || true
        gnome-extensions-cli install blur-my-shell@aunetx || true
        gnome-extensions-cli install dash-to-panel@jderose9.github.com || true
        gnome-extensions-cli install just-perfection-desktop@just-perfection || true
        log "GNOME Extensions" "Gnome extensions installed - log out/in (or restart GNOME Shell) to activate it"
    fi
else
    log "GNOME extensions" "No desktop session detected in this shell - skipped GNOME Tweaks/extension installs. Run this script from a terminal inside your GNOME session to pick those up."
fi
#endregion

echo
log "Done" "Setup complete."
echo "Next: run ./02.Configure-Fedora.sh --run (from your GNOME session) to apply preference settings,"
echo "then log out and back in (or reboot) so GNOME extensions and group changes take full effect."
