#!/usr/bin/env bash
#
# 05.Secure-Fedora.sh
#
# Applies reasonable, reversible security hardening to a Fedora Workstation
# (GNOME) laptop - or reverts any of the same categories back to Fedora's
# out-of-box defaults - or reports Expected vs Found state for every setting
# it manages. This is the Fedora counterpart to 05.Secure-Windows.ps1,
# mirroring its category list, its three modes (Harden / --restore-defaults /
# --report), and its --all switch as closely as the two operating systems
# allow.
#
# Every category is written to be idempotent - safe to re-run. Must be run
# as root (sudo ./05.Secure-Fedora.sh ...). Run with no options to show this
# help - nothing changes until you pick --all or at least one category.
#
# ---------------------------------------------------------------------------
# CATEGORIES
#
#   --firewall
#       Harden: firewalld enabled+running, dropped-packet logging turned on
#       (log-denied=all). Warns (does not force) if the default zone is
#       "trusted", since forcing it to public could break local file/printer
#       sharing you've intentionally set up.
#       Restore: log-denied back to off (stock default). firewalld itself is
#       left enabled/running - that already matches Fedora's stock state,
#       included for completeness (same reasoning as the Windows script's
#       Firewall restore).
#
#   --selinux
#       Harden: SELinux set to Enforcing (both runtime and /etc/selinux/config).
#       Restore: no-op note - Fedora already ships SELinux Enforcing by
#       default, so there is nothing weaker to revert to.
#
#   --luks
#       Report/harden-status only for whole-disk encryption. Unlike
#       BitLocker, LUKS cannot be enabled in-place on an already-installed
#       Fedora system without reformatting. Harden mode reports what it
#       finds and tells you how to actually do this (reinstall with
#       "Encrypt my data" checked). Restore is not offered (decrypting a
#       LUKS volume in place is destructive and not automated here, same
#       spirit as the Windows script declining to re-enable SMBv1).
#
#   --ssh
#       Harden: disables sshd entirely (Fedora Workstation's stock state),
#       OR with --keep-ssh, leaves it enabled and applies a hardened drop-in:
#       root login disabled, empty passwords disabled, X11 forwarding off,
#       MaxAuthTries lowered, idle client timeout set. With
#       --keep-password-auth left off, password authentication is disabled
#       too (key-based only) - UNLESS no authorized_keys file can be found
#       anywhere, in which case the script refuses to disable password auth
#       so you can't lock yourself out. The hardening drop-in is written
#       either way, so it's already in place if sshd is started later.
#       Restore: removes the drop-in config and disables sshd, back to
#       Fedora Workstation's stock sshd state (PermitRootLogin
#       prohibit-password, PasswordAuthentication yes, service disabled).
#
#   --keep-ssh
#       Modifier for --ssh: keep sshd enabled (hardened) instead of
#       disabling it. Same as the Mac script's --keep-ssh and the Windows
#       script's -KeepSsh. Ignored in --restore-defaults mode.
#
#   --keep-password-auth
#       Modifier for --ssh: keep SSH password authentication enabled, but
#       still apply every other SSH hardening item. Ignored in
#       --restore-defaults mode (restore always fully reverts).
#
#   --network-discovery
#       Harden: disables Avahi (mDNS) and disables LLMNR/MulticastDNS in
#       systemd-resolved - the closest Linux analogues to Windows' LLMNR/
#       NetBIOS broadcast discovery.
#       Restore: re-enables Avahi (Fedora Workstation's stock state) and
#       removes the systemd-resolved overrides.
#
#   --sudo
#       Harden: sudo always re-prompts for a password (timestamp_timeout=0),
#       sessions run through a pty, and sudo actions are logged - the
#       closest Linux analogue to Windows' UAC "Always Notify".
#       Restore: removes the drop-in, back to Fedora's stock sudoers
#       (5-minute timestamp cache, no dedicated sudo log).
#
#   --services
#       Harden: disables rpcbind, nfs-server, telnet.socket, smb (Samba file
#       sharing), and gnome-remote-desktop (GNOME Remote Desktop/Screen
#       Sharing) if present - rarely-needed network services, same idea as
#       the Windows script's RemoteRegistry/WMPNetworkSvc and the Mac
#       script's --sharing.
#       Restore: sets them back to disabled/not-started, which is already
#       Fedora Workstation's stock state for all of them.
#
#   --lockscreen
#       Harden: 10-minute idle screen lock (GNOME), autorun/automount
#       disabled for removable media - applied machine-wide via the dconf
#       system database (the closest Linux analogue to a Windows HKLM
#       policy key) and locked so a user session can't override it. Also
#       disables GDM automatic login if it was configured (same as the Mac
#       and Windows scripts).
#       Restore: removes the dconf override + lock files. Automatic login
#       is left disabled - re-enabling passwordless login isn't offered.
#
#   --audit
#       Harden: installs/enables auditd, adds rules watching
#       /etc/passwd, /etc/group, /etc/shadow, sudoers, the faillock
#       database, and privileged (setuid-root) execve calls - the closest
#       Linux analogue to Windows' logon/account-management/privilege-use
#       auditing.
#       Restore: removes the added rule file. auditd itself is left running
#       (stopping a security logging service isn't offered, same caution
#       as several Windows restore paths).
#
#   --credential-hardening
#       Harden: pam_faillock enabled via authselect (15-minute lockout
#       after 10 bad attempts), password quality raised to a 14-character
#       minimum with at least 3 of 4 character classes (lowercase,
#       uppercase, digits, symbols) - the same baseline as the Windows and
#       Mac scripts. Reports (does not force)
#       whether "nullok" appears in any authselect-managed PAM file.
#       Restore: pam_faillock feature disabled again, pwquality reverted to
#       Fedora's stock 8-character minimum with no complexity requirement.
#
#   --attack-surface-extras
#       Harden: kernel/network sysctl hardening (kptr_restrict, ptrace_scope,
#       dmesg_restrict, rp_filter, SYN cookies, no core dumps, protected
#       symlinks/hardlinks), rare legacy filesystem kernel modules
#       blacklisted, and the ctrl-alt-del reboot target masked.
#       Restore: sysctl drop-in removed and reloaded, core-dump limit
#       removed, filesystem blacklist removed, ctrl-alt-del target unmasked.
#
#   --privacy
#       Harden: ABRT automatic problem reporting turned off, NetworkManager
#       connectivity-checking turned off, GNOME "recent files" tracking
#       turned off - the closest Linux analogues to Windows' diagnostic
#       telemetry / activity history settings (Fedora has no advertising ID
#       or Copilot-style features to turn off in the first place).
#       Restore: all three reverted to Fedora Workstation's stock (more
#       permissive) defaults.
#
#   --privacy-strict
#       NOT included in --all - opt in explicitly. Harden: disables GNOME
#       location services machine-wide and locks camera devices down to
#       root-only via a udev rule. THE CAMERA CHANGE WILL BREAK Zoom, Teams,
#       and any other app needing the webcam until reverted. (Unlike
#       Windows, Linux has no safe machine-wide way to block only the
#       microphone without also disabling speaker/audio output through the
#       same driver stack, and Fedora GNOME has no built-in cross-device
#       clipboard sync to disable - both are reported as N/A rather than
#       guessed at.)
#       Restore: location + camera udev rule removed.
#
#   --firefox
#       Harden: applies a set of Firefox enterprise policies via
#       policies.json - telemetry/studies/Pocket off, third-party cookies
#       blocked, network prediction off, DNS-over-HTTPS on. The
#       DNS-over-HTTPS change routes DNS through Cloudflare/Mozilla's
#       resolver and can interfere with split-horizon/internal DNS names on
#       a homelab - review before enabling if that applies to you.
#       Restore: the added policy keys are removed from policies.json,
#       Firefox's own defaults apply again.
#
#   --firefox-strict
#       NOT included in --all - opt in explicitly. Harden: escalates
#       tracking protection to Strict and locks it, disables Firefox Sync,
#       disables the built-in password manager, disables search-suggest,
#       blocks bypassing invalid-certificate/Safe-Browsing warnings, and
#       forces HTTPS-Only mode. HTTPS-Only mode will break any plain-HTTP
#       intranet/homelab page you browse to, same caveat as the Windows
#       script's EdgeStrict.
#       Restore: all of the above removed from policies.json.
#
#   --sysmon
#       Installs Microsoft's official "Sysmon for Linux" via Microsoft's
#       package repo, then applies Microsoft's own MSTIC-Sysmon baseline
#       config (the closest available analogue to the SwiftOnSecurity
#       config used on the Windows side - there is no equally
#       well-established community baseline for Linux).
#       Restore: uninstalls Sysmon (no Sysmon = the Fedora default, since
#       it isn't a built-in component).
#       NOTE: this downloads and executes an installer from the internet.
#       Review $sysmon_repo_rpm_url / $sysmon_config_url below before
#       running if you want to verify them yourself first.
#
#   --auto-update
#       Harden: installs dnf's automatic-update plugin and enables its
#       timer to download and apply security updates daily - the Fedora
#       counterpart to the Mac script's --software-update (Windows Update
#       is already automatic by default). Does NOT install anything pending
#       right now; use --dnf-update for that.
#       Restore: timer disabled and this script's config removed (Fedora's
#       stock state - no automatic updates).
#
#   --dnf-update
#       Runs 'dnf upgrade -y'. Report mode adds a pending-package-count row
#       instead of installing. Not affected by --restore-defaults.
#
#   --flatpak-update
#       Runs 'flatpak update -y' (skipped if flatpak isn't installed).
#       Report mode adds a pending-update-count row instead of installing.
#       Not affected by --restore-defaults.
#
#   --separate-admin
#       NOT included in --all - opt in explicitly. Always runs last.
#       Harden: creates a separate local admin account (--new-admin NAME,
#       or you're asked for one) in the wheel group, then removes the user
#       who ran sudo (or --demote-user NAME) from wheel, so day-to-day work
#       happens in a standard account. Safety checks, in order - any failure
#       stops BEFORE your account is demoted:
#         1. you type YES to confirm the plan;
#         2. passwd sets the new account's password (typed twice, and
#            checked against --credential-hardening's password rules);
#            if that fails the half-created account is removed again;
#         3. it must be in wheel, have a password set, and sudo must
#            actually grant it (ALL) ALL.
#       If the admin account already exists it's reused (check 3 still
#       applies). Sessions you already have open keep sudo until you log
#       out - log out and back in for the change to take full effect.
#       Report: shows whether the user is in wheel, and whether a separate
#       admin account exists.
#       Restore: adds --demote-user back to wheel. Run it from the admin
#       account, e.g.
#       sudo ./05.Secure-Fedora.sh --separate-admin --demote-user alice --restore-defaults
#       The admin account is left in place - deleting accounts isn't offered.
#
#   --new-admin NAME
#       Modifier for --separate-admin: name of the admin account to create
#       or reuse.
#
#   --demote-user NAME
#       Modifier for --separate-admin: the account to remove from (or, on
#       restore, add back to) wheel. Default: the user who ran sudo.
#
#   --all
#       Runs every category above EXCEPT --privacy-strict, --firefox-strict
#       and --separate-admin, which are opt-in only.
#
#   --restore-defaults
#       Reverts the selected categories to Fedora out-of-box defaults
#       instead of hardening them. Cannot be combined with --report.
#
#   --report
#       For each selected category, prints a table with one row per
#       setting: Category, Setting, Expected, Found, Status (OK/MISMATCH).
#       Makes no changes. Cannot be combined with --restore-defaults.
#
# EXAMPLES
#   sudo ./05.Secure-Fedora.sh --all
#   sudo ./05.Secure-Fedora.sh --firewall --ssh --sudo --selinux
#   sudo ./05.Secure-Fedora.sh --all --report
#   sudo ./05.Secure-Fedora.sh --ssh --sudo --restore-defaults
#   sudo ./05.Secure-Fedora.sh --ssh --keep-ssh
#   sudo ./05.Secure-Fedora.sh --dnf-update --flatpak-update
#   sudo ./05.Secure-Fedora.sh --separate-admin --new-admin localadmin
#
# ---------------------------------------------------------------------------

set -u

#region Setup

ALL=0
FIREWALL=0
SELINUX=0
LUKS=0
SSH=0
KEEP_SSH=0
KEEP_PASSWORD_AUTH=0
NETWORK_DISCOVERY=0
SUDO_HARDENING=0
SERVICES=0
LOCKSCREEN=0
AUDIT=0
CREDENTIAL_HARDENING=0
ATTACK_SURFACE_EXTRAS=0
PRIVACY=0
PRIVACY_STRICT=0
AUTO_UPDATE=0
FIREFOX=0
FIREFOX_STRICT=0
SYSMON=0
DNF_UPDATE=0
FLATPAK_UPDATE=0
SEPARATE_ADMIN=0
NEW_ADMIN=""
DEMOTE_USER=""
RESTORE_DEFAULTS=0
REPORT=0

print_usage() {
    # The header comment block at the top of this file, minus the shebang.
    awk 'NR == 1 { next } !/^#/ { exit } { sub(/^# ?/, ""); print }' "$0"
}

if [[ $# -eq 0 ]]; then
    print_usage
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) ALL=1 ;;
        --firewall) FIREWALL=1 ;;
        --selinux) SELINUX=1 ;;
        --luks) LUKS=1 ;;
        --ssh) SSH=1 ;;
        --keep-ssh) KEEP_SSH=1 ;;
        --keep-password-auth) KEEP_PASSWORD_AUTH=1 ;;
        --network-discovery) NETWORK_DISCOVERY=1 ;;
        --sudo) SUDO_HARDENING=1 ;;
        --services) SERVICES=1 ;;
        --lockscreen) LOCKSCREEN=1 ;;
        --audit) AUDIT=1 ;;
        --credential-hardening) CREDENTIAL_HARDENING=1 ;;
        --attack-surface-extras) ATTACK_SURFACE_EXTRAS=1 ;;
        --privacy) PRIVACY=1 ;;
        --privacy-strict) PRIVACY_STRICT=1 ;;
        --auto-update) AUTO_UPDATE=1 ;;
        --firefox) FIREFOX=1 ;;
        --firefox-strict) FIREFOX_STRICT=1 ;;
        --sysmon) SYSMON=1 ;;
        --dnf-update) DNF_UPDATE=1 ;;
        --flatpak-update) FLATPAK_UPDATE=1 ;;
        --separate-admin) SEPARATE_ADMIN=1 ;;
        --new-admin) NEW_ADMIN="${2:-}"; shift ;;
        --demote-user) DEMOTE_USER="${2:-}"; shift ;;
        --restore-defaults) RESTORE_DEFAULTS=1 ;;
        --report) REPORT=1 ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo "Unknown option: $1 (run with --help)" >&2; exit 1 ;;
    esac
    shift
done

# Checked after parsing so --help (and no options) work without sudo, or off Fedora.
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Re-run with sudo." >&2
    exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
    echo "dnf not found - this script is written for Fedora." >&2
    exit 1
fi

if [[ $REPORT -eq 1 && $RESTORE_DEFAULTS -eq 1 ]]; then
    echo "--report and --restore-defaults cannot be combined - pick one." >&2
    exit 1
fi

if [[ $ALL -eq 1 ]]; then
    FIREWALL=1; SELINUX=1; LUKS=1; SSH=1; NETWORK_DISCOVERY=1
    SUDO_HARDENING=1; SERVICES=1; LOCKSCREEN=1; AUDIT=1
    CREDENTIAL_HARDENING=1; ATTACK_SURFACE_EXTRAS=1; PRIVACY=1
    AUTO_UPDATE=1; FIREFOX=1; SYSMON=1; DNF_UPDATE=1; FLATPAK_UPDATE=1
    # PRIVACY_STRICT, FIREFOX_STRICT and SEPARATE_ADMIN are opt-in only, not set by --all.
fi

if [[ $((FIREWALL + SELINUX + LUKS + SSH + NETWORK_DISCOVERY + SUDO_HARDENING + \
        SERVICES + LOCKSCREEN + AUDIT + CREDENTIAL_HARDENING + ATTACK_SURFACE_EXTRAS + \
        PRIVACY + PRIVACY_STRICT + AUTO_UPDATE + FIREFOX + FIREFOX_STRICT + SYSMON + DNF_UPDATE + \
        FLATPAK_UPDATE + SEPARATE_ADMIN)) -eq 0 ]]; then
    echo "No categories selected. Use --all or specific flags. Run with --help for details."
    exit 0
fi

if [[ $REPORT -eq 1 ]]; then
    MODE="report"
elif [[ $RESTORE_DEFAULTS -eq 1 ]]; then
    MODE="restore"
else
    MODE="harden"
fi

declare -a RESULTS=()
declare -a REPORT_ROWS=()

log() {
    local category="$1" action="$2" status="$3"
    RESULTS+=("${category}"$'\t'"${action}"$'\t'"${status}")
    echo "[$category] $action -> $status"
}

report_row() {
    local category="$1" setting="$2" expected="$3" found="$4" status="OK"
    [[ "$expected" != "$found" ]] && status="MISMATCH"
    REPORT_ROWS+=("${category}"$'\t'"${setting}"$'\t'"${expected}"$'\t'"${found}"$'\t'"${status}")
}

#endregion

#region Firewall
if [[ $FIREWALL -eq 1 ]]; then
    if [[ "$MODE" == "report" ]]; then
        if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
            state="running"
        else
            state="not running"
        fi
        report_row "Firewall" "firewalld state" "running" "$state"

        zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo "unknown")
        report_row "Firewall" "Default zone is not 'trusted'" "true" "$([[ "$zone" != "trusted" ]] && echo true || echo false)"

        logdenied=$(firewall-cmd --get-log-denied 2>/dev/null || echo "unknown")
        report_row "Firewall" "Dropped-packet logging (log-denied)" "all" "$logdenied"
    elif [[ "$MODE" == "restore" ]]; then
        firewall-cmd --set-log-denied=off >/dev/null 2>&1
        log "Firewall" "Dropped-packet logging" "Reverted to Fedora default (off)"
        log "Firewall" "firewalld enabled/running" "Left as-is - already Fedora's stock state"
    else
        systemctl enable --now firewalld >/dev/null 2>&1
        log "Firewall" "firewalld enabled and running" "Done"

        firewall-cmd --set-log-denied=all >/dev/null 2>&1
        log "Firewall" "Dropped-packet logging" "Enabled (log-denied=all)"

        zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo "unknown")
        if [[ "$zone" == "trusted" ]]; then
            log "Firewall" "Default zone check" "WARNING: default zone is 'trusted' (allows all traffic) - not changed automatically since that may be intentional; review with 'firewall-cmd --get-default-zone'"
        else
            log "Firewall" "Default zone check" "OK ($zone, not trusted)"
        fi
    fi
fi
#endregion

#region SELinux
if [[ $SELINUX -eq 1 ]]; then
    cfg_file="/etc/selinux/config"
    if [[ "$MODE" == "report" ]]; then
        runtime=$(getenforce 2>/dev/null || echo "Unknown")
        report_row "SELinux" "Runtime mode" "Enforcing" "$runtime"
        cfgval=$(grep -E '^SELINUX=' "$cfg_file" 2>/dev/null | cut -d= -f2)
        report_row "SELinux" "Configured mode (/etc/selinux/config)" "enforcing" "${cfgval:-unknown}"
    elif [[ "$MODE" == "restore" ]]; then
        log "SELinux" "Restore" "No-op - Fedora ships SELinux Enforcing by default, nothing weaker to revert to"
    else
        runtime=$(getenforce 2>/dev/null || echo "Unknown")
        if [[ "$runtime" == "Disabled" ]]; then
            log "SELinux" "Set Enforcing" "Cannot flip at runtime - SELinux is Disabled in the running kernel. Edit $cfg_file (SELINUX=enforcing) and reboot."
        else
            setenforce 1 2>/dev/null
            log "SELinux" "Runtime mode" "Set to Enforcing"
        fi
        if [[ -f "$cfg_file" ]]; then
            sed -i 's/^SELINUX=.*/SELINUX=enforcing/' "$cfg_file"
            log "SELinux" "Configured mode" "Set to enforcing in $cfg_file"
        fi
    fi
fi
#endregion

#region LUKS (disk encryption - report/status only, see header notes)
if [[ $LUKS -eq 1 ]]; then
    root_src=$(findmnt -no SOURCE / 2>/dev/null || echo "")
    is_luks="No"
    if [[ -n "$root_src" ]]; then
        pkname=$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -1)
        [[ -n "$pkname" ]] && root_src="/dev/$pkname"
        fstype=$(blkid -o value -s TYPE "$root_src" 2>/dev/null || echo "")
        [[ "$fstype" == "crypto_LUKS" ]] && is_luks="Yes"
    fi

    if [[ "$MODE" == "report" ]]; then
        report_row "LUKS" "Root filesystem is on a LUKS-encrypted volume" "Yes" "$is_luks"
    elif [[ "$MODE" == "restore" ]]; then
        log "LUKS" "Restore" "Not offered - decrypting a LUKS volume in place is destructive and isn't automated here"
    else
        if [[ "$is_luks" == "Yes" ]]; then
            log "LUKS" "Encryption status" "Already encrypted"
        else
            log "LUKS" "Encryption status" "NOT encrypted - Fedora cannot enable LUKS on an already-installed system without reformatting. To fix this: back up your data and reinstall Fedora with 'Encrypt my data' checked in the installer."
        fi
    fi
fi
#endregion

#region SSH
if [[ $SSH -eq 1 ]]; then
    # sshd uses the FIRST value it reads for each keyword, and drop-ins are
    # read in lexical order - so this has to sort before Fedora's own
    # 50-redhat.conf (which sets X11Forwarding yes) and the installer's
    # 01-permitrootlogin.conf, or those would silently win.
    drop_in="/etc/ssh/sshd_config.d/00-hardening.conf"
    legacy_drop_in="/etc/ssh/sshd_config.d/99-hardening.conf"
    have_sshd=0
    command -v sshd >/dev/null 2>&1 && have_sshd=1

    any_authorized_keys() {
        while IFS=: read -r _ _ _ _ _ home _; do
            [[ -s "$home/.ssh/authorized_keys" ]] && return 0
        done < /etc/passwd
        return 1
    }

    if [[ "$MODE" == "report" ]]; then
        if [[ $have_sshd -eq 0 ]]; then
            report_row "SSH" "sshd installed" "Yes" "No"
        else
            expected_svc="disabled"; [[ $KEEP_SSH -eq 1 ]] && expected_svc="enabled"
            report_row "SSH" "sshd service" "$expected_svc" "$(systemctl is-enabled sshd 2>/dev/null || echo unknown)"
            root_login=$(sshd -T 2>/dev/null | awk '/^permitrootlogin/{print $2}')
            report_row "SSH" "PermitRootLogin" "no" "${root_login:-unknown}"
            pwauth=$(sshd -T 2>/dev/null | awk '/^passwordauthentication/{print $2}')
            expected_pwauth="no"; [[ $KEEP_PASSWORD_AUTH -eq 1 ]] && expected_pwauth="yes"
            report_row "SSH" "PasswordAuthentication" "$expected_pwauth" "${pwauth:-unknown}"
            emptypw=$(sshd -T 2>/dev/null | awk '/^permitemptypasswords/{print $2}')
            report_row "SSH" "PermitEmptyPasswords" "no" "${emptypw:-unknown}"
            x11=$(sshd -T 2>/dev/null | awk '/^x11forwarding/{print $2}')
            report_row "SSH" "X11Forwarding" "no" "${x11:-unknown}"
            maxtries=$(sshd -T 2>/dev/null | awk '/^maxauthtries/{print $2}')
            report_row "SSH" "MaxAuthTries" "4" "${maxtries:-unknown}"
        fi
    elif [[ "$MODE" == "restore" ]]; then
        if [[ -f "$drop_in" || -f "$legacy_drop_in" ]]; then
            rm -f "$drop_in" "$legacy_drop_in"
            log "SSH" "Hardening drop-in removed" "Reverted to Fedora stock sshd defaults (PermitRootLogin prohibit-password, PasswordAuthentication yes)"
        else
            log "SSH" "Restore" "No hardening drop-in present - nothing to revert"
        fi
        if [[ $have_sshd -eq 1 ]]; then
            systemctl disable --now sshd >/dev/null 2>&1
            log "SSH" "sshd service" "Disabled (Fedora Workstation default)"
        fi
    else
        if [[ $have_sshd -eq 0 ]]; then
            log "SSH" "Harden" "Skipped - sshd is not installed on this system"
        else
            rm -f "$legacy_drop_in"
            {
                echo "# Managed by secure-fedora.sh - do not edit by hand"
                echo "PermitRootLogin no"
                echo "PermitEmptyPasswords no"
                echo "X11Forwarding no"
                echo "MaxAuthTries 4"
                echo "ClientAliveInterval 300"
                echo "ClientAliveCountMax 2"
                if [[ $KEEP_PASSWORD_AUTH -eq 1 ]]; then
                    echo "PasswordAuthentication yes"
                elif any_authorized_keys; then
                    echo "PasswordAuthentication no"
                else
                    echo "# PasswordAuthentication left at its configured value - no authorized_keys"
                    echo "# file was found for any user, so disabling password auth was skipped to"
                    echo "# avoid locking you out. Add a key and re-run without --keep-password-auth."
                fi
            } > "$drop_in"
            if [[ $KEEP_PASSWORD_AUTH -eq 1 ]]; then
                pw_note="password auth kept enabled"
            elif any_authorized_keys; then
                pw_note="password auth disabled (key-based only)"
            else
                pw_note="password auth left enabled - no authorized_keys found for any user, refused to disable it to avoid lockout"
            fi

            if [[ $KEEP_SSH -eq 1 ]]; then
                systemctl enable --now sshd >/dev/null 2>&1
                systemctl try-restart sshd >/dev/null 2>&1
                log "SSH" "sshd kept enabled, hardened ($pw_note)" "Done"
            else
                systemctl disable --now sshd >/dev/null 2>&1
                log "SSH" "sshd disabled (hardening drop-in also written: $pw_note)" "Done"
            fi
        fi
    fi
fi
#endregion

#region Network discovery (Avahi/mDNS, LLMNR)
if [[ $NETWORK_DISCOVERY -eq 1 ]]; then
    resolved_dropin="/etc/systemd/resolved.conf.d/99-hardening.conf"

    if [[ "$MODE" == "report" ]]; then
        avahi_state=$(systemctl is-enabled avahi-daemon.service 2>/dev/null || echo "not-installed")
        report_row "Network" "avahi-daemon disabled" "disabled" "$avahi_state"
        llmnr_conf=$(grep -E '^\s*LLMNR=' /etc/systemd/resolved.conf "$resolved_dropin" 2>/dev/null | tail -1 | cut -d= -f2)
        report_row "Network" "systemd-resolved LLMNR" "no" "${llmnr_conf:-yes (default)}"
        mdns_conf=$(grep -E '^\s*MulticastDNS=' /etc/systemd/resolved.conf "$resolved_dropin" 2>/dev/null | tail -1 | cut -d= -f2)
        report_row "Network" "systemd-resolved MulticastDNS" "no" "${mdns_conf:-yes (default)}"
    elif [[ "$MODE" == "restore" ]]; then
        systemctl enable --now avahi-daemon.service avahi-daemon.socket >/dev/null 2>&1
        log "Network" "avahi-daemon" "Reverted to Fedora Workstation default (enabled)"
        rm -f "$resolved_dropin"
        systemctl restart systemd-resolved >/dev/null 2>&1
        log "Network" "systemd-resolved LLMNR/MulticastDNS" "Overrides removed - back to default (both enabled)"
    else
        systemctl disable --now avahi-daemon.service avahi-daemon.socket >/dev/null 2>&1
        log "Network" "avahi-daemon disabled" "Done"
        mkdir -p "$(dirname "$resolved_dropin")"
        printf '[Resolve]\nLLMNR=no\nMulticastDNS=no\n' > "$resolved_dropin"
        systemctl restart systemd-resolved >/dev/null 2>&1
        log "Network" "systemd-resolved LLMNR + MulticastDNS disabled" "Done"
    fi
fi
#endregion

#region Sudo hardening (UAC analogue)
if [[ $SUDO_HARDENING -eq 1 ]]; then
    sudoers_dropin="/etc/sudoers.d/99-hardening"

    if [[ "$MODE" == "report" ]]; then
        if [[ -f "$sudoers_dropin" ]]; then
            report_row "Sudo" "timestamp_timeout" "0" "$(grep -oP 'timestamp_timeout=\K\S+' "$sudoers_dropin" 2>/dev/null || echo unset)"
            report_row "Sudo" "use_pty" "set" "$(grep -q 'use_pty' "$sudoers_dropin" && echo set || echo unset)"
            report_row "Sudo" "logfile" "/var/log/sudo.log" "$(grep -oP 'logfile="\K[^"]+' "$sudoers_dropin" 2>/dev/null || echo unset)"
        else
            report_row "Sudo" "Hardening drop-in present" "yes" "no"
        fi
    elif [[ "$MODE" == "restore" ]]; then
        rm -f "$sudoers_dropin"
        log "Sudo" "Hardening drop-in removed" "Reverted to Fedora stock sudo defaults (5-minute credential cache, no dedicated log)"
    else
        {
            echo "# Managed by secure-fedora.sh - do not edit by hand"
            echo 'Defaults timestamp_timeout=0'
            echo 'Defaults use_pty'
            echo 'Defaults passwd_tries=3'
            echo 'Defaults logfile="/var/log/sudo.log"'
        } > "$sudoers_dropin"
        chmod 0440 "$sudoers_dropin"
        if visudo -cf "$sudoers_dropin" >/dev/null 2>&1; then
            log "Sudo" "Always re-prompt for password, pty required, actions logged" "Done"
        else
            rm -f "$sudoers_dropin"
            log "Sudo" "Harden" "FAILED visudo syntax check - drop-in removed, nothing applied"
        fi
    fi
fi
#endregion

#region Services
if [[ $SERVICES -eq 1 ]]; then
    services_to_disable=(rpcbind.service nfs-server.service telnet.socket smb.service gnome-remote-desktop.service)
    for svc in "${services_to_disable[@]}"; do
        if ! systemctl list-unit-files "$svc" >/dev/null 2>&1 || ! systemctl list-unit-files "$svc" 2>/dev/null | grep -q "$svc"; then
            continue
        fi
        if [[ "$MODE" == "report" ]]; then
            state=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
            report_row "Services" "$svc disabled" "disabled" "$state"
        elif [[ "$MODE" == "restore" ]]; then
            systemctl disable --now "$svc" >/dev/null 2>&1
            log "Services" "$svc" "Left disabled - already Fedora Workstation's stock state"
        else
            systemctl disable --now "$svc" >/dev/null 2>&1
            log "Services" "$svc disabled" "Done"
        fi
    done
fi
#endregion

#region Lockscreen / removable media (dconf system-wide policy)
if [[ $LOCKSCREEN -eq 1 ]]; then
    dconf_dir="/etc/dconf/db/local.d"
    dconf_locks_dir="/etc/dconf/db/local.d/locks"
    dconf_file="$dconf_dir/00-hardening"
    dconf_lock_file="$dconf_locks_dir/00-hardening"
    profile_file="/etc/dconf/profile/user"
    gdm_conf="/etc/gdm/custom.conf"
    autologin=$(grep -oP '^\s*AutomaticLoginEnable\s*=\s*\K\w+' "$gdm_conf" 2>/dev/null | tail -1)

    if [[ "$MODE" == "report" ]]; then
        idle=$(grep -A2 '\[org/gnome/desktop/session\]' "$dconf_file" 2>/dev/null | grep -oP 'idle-delay=uint32 \K\d+' || echo "not set")
        report_row "Lockscreen" "Idle delay (seconds)" "600" "$idle"
        lock=$(grep -A5 '\[org/gnome/desktop/screensaver\]' "$dconf_file" 2>/dev/null | grep -oP 'lock-enabled=\K\w+' || echo "not set")
        report_row "Lockscreen" "Screensaver lock-enabled" "true" "$lock"
        automount=$(grep -A5 '\[org/gnome/desktop/media-handling\]' "$dconf_file" 2>/dev/null | grep -oP 'automount=\K\w+' || echo "not set")
        report_row "Lockscreen" "Automount removable media" "false" "$automount"
        report_row "Lockscreen" "GDM automatic login" "false" "${autologin:-false}"
    elif [[ "$MODE" == "restore" ]]; then
        rm -f "$dconf_file" "$dconf_lock_file"
        dconf update
        log "Lockscreen" "dconf overrides removed" "Reverted to Fedora Workstation defaults (screen blank/lock timing, automount left to the user's own setting)"
        log "Lockscreen" "Automatic login" "Left disabled - re-enabling passwordless login isn't offered"
    else
        mkdir -p "$dconf_dir" "$dconf_locks_dir"
        cat > "$dconf_file" <<'EOF'
# Managed by secure-fedora.sh - do not edit by hand
[org/gnome/desktop/session]
idle-delay=uint32 600

[org/gnome/desktop/screensaver]
lock-enabled=true
lock-delay=uint32 0

[org/gnome/desktop/media-handling]
automount=false
automount-open=false
EOF
        cat > "$dconf_lock_file" <<'EOF'
/org/gnome/desktop/session/idle-delay
/org/gnome/desktop/screensaver/lock-enabled
/org/gnome/desktop/screensaver/lock-delay
/org/gnome/desktop/media-handling/automount
/org/gnome/desktop/media-handling/automount-open
EOF
        if [[ -f "$profile_file" ]] && ! grep -q '^system-db:local' "$profile_file"; then
            echo 'system-db:local' >> "$profile_file"
        elif [[ ! -f "$profile_file" ]]; then
            printf 'user-db:user\nsystem-db:local\n' > "$profile_file"
        fi
        dconf update
        log "Lockscreen" "10-minute idle lock + autorun/automount disabled (machine-wide, locked)" "Done"

        if [[ "${autologin,,}" == "true" ]]; then
            sed -i -E 's/^(\s*AutomaticLoginEnable\s*=\s*).*/\1false/I' "$gdm_conf"
            log "Lockscreen" "Automatic login" "Disabled in $gdm_conf (takes effect at next boot)"
        else
            log "Lockscreen" "Automatic login" "Already disabled"
        fi
    fi
fi
#endregion

#region Audit (auditd)
if [[ $AUDIT -eq 1 ]]; then
    rules_file="/etc/audit/rules.d/99-hardening.rules"

    if [[ "$MODE" == "report" ]]; then
        auditd_state=$(systemctl is-active auditd 2>/dev/null || echo "not-installed")
        report_row "Audit" "auditd running" "active" "$auditd_state"
        report_row "Audit" "Hardening rules loaded" "yes" "$([[ -f "$rules_file" ]] && echo yes || echo no)"
    elif [[ "$MODE" == "restore" ]]; then
        if [[ -f "$rules_file" ]]; then
            rm -f "$rules_file"
            augenrules --load >/dev/null 2>&1
            log "Audit" "Hardening rules removed" "auditd left running; only the extra rules were reverted (stopping the audit subsystem entirely isn't offered)"
        else
            log "Audit" "Restore" "No hardening rules present - nothing to revert"
        fi
    else
        if ! command -v auditctl >/dev/null 2>&1; then
            dnf install -y audit >/dev/null 2>&1
        fi
        systemctl enable --now auditd >/dev/null 2>&1
        cat > "$rules_file" <<'EOF'
# Managed by secure-fedora.sh - do not edit by hand
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege_escalation
-w /etc/sudoers.d/ -p wa -k privilege_escalation
-w /var/run/faillock/ -p wa -k logins
-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k privilege_escalation
-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k privilege_escalation
EOF
        augenrules --load >/dev/null 2>&1
        log "Audit" "Rules for identity files, sudoers, logins, privileged execve" "Applied"
    fi
fi
#endregion

#region Credential hardening
if [[ $CREDENTIAL_HARDENING -eq 1 ]]; then
    pwquality_dropin="/etc/security/pwquality.conf.d/99-hardening.conf"
    faillock_dropin="/etc/security/faillock.conf.d/99-hardening.conf"

    if [[ "$MODE" == "report" ]]; then
        feature_on=$(authselect current 2>/dev/null | grep -q 'with-faillock' && echo enabled || echo disabled)
        report_row "CredentialHardening" "pam_faillock enabled (authselect feature)" "enabled" "$feature_on"
        minlen=$(grep -hoP '^\s*minlen\s*=\s*\K\d+' /etc/security/pwquality.conf "$pwquality_dropin" 2>/dev/null | tail -1)
        report_row "CredentialHardening" "Password minimum length" "14" "${minlen:-8 (default)}"
        minclass=$(grep -hoP '^\s*minclass\s*=\s*\K\d+' /etc/security/pwquality.conf "$pwquality_dropin" 2>/dev/null | tail -1)
        report_row "CredentialHardening" "Required character classes" "3" "${minclass:-0 (default)}"
        deny=$(grep -hoP '^\s*deny\s*=\s*\K\d+' /etc/security/faillock.conf "$faillock_dropin" 2>/dev/null | tail -1)
        report_row "CredentialHardening" "Lockout threshold (bad attempts)" "10" "${deny:-not set}"
        unlock=$(grep -hoP '^\s*unlock_time\s*=\s*\K\d+' /etc/security/faillock.conf "$faillock_dropin" 2>/dev/null | tail -1)
        report_row "CredentialHardening" "Lockout duration (seconds)" "900" "${unlock:-not set}"
        nullok_hits=$(grep -rl 'nullok' /etc/pam.d/ 2>/dev/null | wc -l)
        report_row "CredentialHardening" "PAM files containing 'nullok'" "0" "$nullok_hits"
        report_row "CredentialHardening" "Default guest account" "N/A - Fedora ships no guest account" "N/A - Fedora ships no guest account"
    elif [[ "$MODE" == "restore" ]]; then
        authselect disable-feature with-faillock >/dev/null 2>&1
        rm -f "$pwquality_dropin" "$faillock_dropin"
        log "CredentialHardening" "faillock disabled, pwquality/faillock overrides removed" "Reverted to Fedora stock (no lockout, 8-char minimum password, no complexity requirement)"
    else
        mkdir -p /etc/security/pwquality.conf.d /etc/security/faillock.conf.d
        cat > "$pwquality_dropin" <<'EOF'
# Managed by secure-fedora.sh - do not edit by hand
minlen = 14
minclass = 3
enforce_for_root
EOF
        cat > "$faillock_dropin" <<'EOF'
# Managed by secure-fedora.sh - do not edit by hand
deny = 10
fail_interval = 900
unlock_time = 900
EOF
        authselect enable-feature with-faillock >/dev/null 2>&1
        log "CredentialHardening" "pam_faillock enabled, password minlen=14 with 3 of 4 character classes, 15-minute lockout after 10 attempts" "Done"
        nullok_hits=$(grep -rl 'nullok' /etc/pam.d/ 2>/dev/null | wc -l)
        if [[ "$nullok_hits" -gt 0 ]]; then
            log "CredentialHardening" "nullok check" "WARNING: 'nullok' found in $nullok_hits PAM file(s) under /etc/pam.d - review manually, not changed automatically since PAM files are authselect-managed"
        fi
    fi
fi
#endregion

#region Attack surface extras
if [[ $ATTACK_SURFACE_EXTRAS -eq 1 ]]; then
    sysctl_file="/etc/sysctl.d/99-hardening.conf"
    limits_file="/etc/security/limits.d/99-hardening.conf"
    modprobe_file="/etc/modprobe.d/99-hardening-filesystems.conf"

    declare -A sysctl_expected=(
        [kernel.kptr_restrict]=2
        [kernel.dmesg_restrict]=1
        [kernel.yama.ptrace_scope]=1
        [net.ipv4.conf.all.rp_filter]=1
        [net.ipv4.conf.all.accept_redirects]=0
        [net.ipv4.conf.all.send_redirects]=0
        [net.ipv4.tcp_syncookies]=1
        [fs.suid_dumpable]=0
        [fs.protected_hardlinks]=1
        [fs.protected_symlinks]=1
    )

    if [[ "$MODE" == "report" ]]; then
        for key in "${!sysctl_expected[@]}"; do
            found=$(sysctl -n "$key" 2>/dev/null || echo "unknown")
            report_row "AttackSurfaceExtras" "$key" "${sysctl_expected[$key]}" "$found"
        done
        report_row "AttackSurfaceExtras" "Core dumps disabled (limits.d)" "yes" "$([[ -f "$limits_file" ]] && echo yes || echo no)"
        report_row "AttackSurfaceExtras" "Legacy filesystem modules blacklisted" "yes" "$([[ -f "$modprobe_file" ]] && echo yes || echo no)"
        cad_state=$(systemctl is-enabled ctrl-alt-del.target 2>/dev/null || echo "unknown")
        report_row "AttackSurfaceExtras" "ctrl-alt-del.target" "masked" "$cad_state"
    elif [[ "$MODE" == "restore" ]]; then
        rm -f "$sysctl_file"
        sysctl --system >/dev/null 2>&1
        rm -f "$limits_file"
        rm -f "$modprobe_file"
        systemctl unmask ctrl-alt-del.target >/dev/null 2>&1
        log "AttackSurfaceExtras" "sysctl/limits/modprobe overrides removed, ctrl-alt-del unmasked" "Reverted to Fedora defaults"
    else
        {
            echo "# Managed by secure-fedora.sh - do not edit by hand"
            for key in "${!sysctl_expected[@]}"; do
                echo "$key = ${sysctl_expected[$key]}"
            done
        } > "$sysctl_file"
        sysctl --system >/dev/null 2>&1
        log "AttackSurfaceExtras" "Kernel/network sysctl hardening" "Applied"

        echo "* hard core 0" > "$limits_file"
        log "AttackSurfaceExtras" "Core dumps" "Disabled for all users"

        {
            for fs in cramfs freevxfs jffs2 hfs hfsplus udf; do
                echo "install $fs /bin/true"
            done
        } > "$modprobe_file"
        log "AttackSurfaceExtras" "Legacy filesystem modules (cramfs, freevxfs, jffs2, hfs, hfsplus, udf)" "Blacklisted"

        systemctl mask ctrl-alt-del.target >/dev/null 2>&1
        log "AttackSurfaceExtras" "ctrl-alt-del.target" "Masked (accidental/physical-access reboot via Ctrl+Alt+Del disabled)"
    fi
    unset sysctl_expected
fi
#endregion

#region Privacy
if [[ $PRIVACY -eq 1 ]]; then
    nm_dropin="/etc/NetworkManager/conf.d/99-hardening.conf"
    dconf_dir="/etc/dconf/db/local.d"
    dconf_file="$dconf_dir/01-privacy"
    profile_file="/etc/dconf/profile/user"

    if [[ "$MODE" == "report" ]]; then
        abrt_state=$(systemctl is-enabled abrtd 2>/dev/null || echo "not-installed")
        report_row "Privacy" "ABRT automatic reporting disabled" "disabled/not-installed" "$abrt_state"
        nm_conn=$(grep -A3 '\[connectivity\]' "$nm_dropin" 2>/dev/null | grep -oP 'enabled=\K\w+' || echo "not set (enabled by default)")
        report_row "Privacy" "NetworkManager connectivity checking" "false" "$nm_conn"
        recent=$(grep -A2 '\[org/gnome/desktop/privacy\]' "$dconf_file" 2>/dev/null | grep -oP 'remember-recent-files=\K\w+' || echo "not set (true by default)")
        report_row "Privacy" "Remember recent files" "false" "$recent"
    elif [[ "$MODE" == "restore" ]]; then
        systemctl enable --now abrtd >/dev/null 2>&1
        rm -f "$nm_dropin"
        systemctl reload NetworkManager >/dev/null 2>&1
        rm -f "$dconf_file"
        dconf update
        log "Privacy" "ABRT re-enabled, connectivity checking + recent-files overrides removed" "Reverted to Fedora Workstation defaults"
    else
        systemctl disable --now abrtd abrt-ccpp >/dev/null 2>&1
        log "Privacy" "ABRT automatic problem reporting" "Disabled"

        mkdir -p "$(dirname "$nm_dropin")"
        printf '[connectivity]\nuri=\ninterval=0\nenabled=false\n' > "$nm_dropin"
        systemctl reload NetworkManager >/dev/null 2>&1
        log "Privacy" "NetworkManager connectivity checking" "Disabled"

        mkdir -p "$dconf_dir"
        cat > "$dconf_file" <<'EOF'
# Managed by secure-fedora.sh - do not edit by hand
[org/gnome/desktop/privacy]
remember-recent-files=false
recent-files-max-age=0
EOF
        if [[ -f "$profile_file" ]] && ! grep -q '^system-db:local' "$profile_file"; then
            echo 'system-db:local' >> "$profile_file"
        elif [[ ! -f "$profile_file" ]]; then
            printf 'user-db:user\nsystem-db:local\n' > "$profile_file"
        fi
        dconf update
        log "Privacy" "Recent-files tracking" "Disabled"
    fi
fi
#endregion

#region Privacy - strict (location, camera; opt-in only)
if [[ $PRIVACY_STRICT -eq 1 ]]; then
    dconf_dir="/etc/dconf/db/local.d"
    dconf_file="$dconf_dir/02-privacy-strict"
    dconf_lock_file="/etc/dconf/db/local.d/locks/02-privacy-strict"
    profile_file="/etc/dconf/profile/user"
    udev_rule="/etc/udev/rules.d/99-hardening-camera.rules"

    if [[ "$MODE" == "report" ]]; then
        loc=$(grep -A2 '\[org/gnome/system/location\]' "$dconf_file" 2>/dev/null | grep -oP 'enabled=\K\w+' || echo "not set (true by default)")
        report_row "PrivacyStrict" "Location services disabled" "false" "$loc"
        report_row "PrivacyStrict" "Camera devices root-only (udev rule)" "yes" "$([[ -f "$udev_rule" ]] && echo yes || echo no)"
        report_row "PrivacyStrict" "Microphone force-block" "N/A - not safely automatable on Linux without disabling shared audio hardware" "N/A - not safely automatable on Linux without disabling shared audio hardware"
        report_row "PrivacyStrict" "Cross-device clipboard sync" "N/A - Fedora GNOME has no built-in feature to disable" "N/A - Fedora GNOME has no built-in feature to disable"
    elif [[ "$MODE" == "restore" ]]; then
        rm -f "$dconf_file" "$dconf_lock_file"
        dconf update
        rm -f "$udev_rule"
        udevadm control --reload-rules && udevadm trigger --subsystem-match=video4linux 2>/dev/null
        log "PrivacyStrict" "Location + camera udev rule removed" "Reverted - camera/location back to the user's own choice"
    else
        mkdir -p "$dconf_dir" "$(dirname "$dconf_lock_file")"
        cat > "$dconf_file" <<'EOF'
# Managed by secure-fedora.sh - do not edit by hand
[org/gnome/system/location]
enabled=false
EOF
        echo '/org/gnome/system/location/enabled' > "$dconf_lock_file"
        if [[ -f "$profile_file" ]] && ! grep -q '^system-db:local' "$profile_file"; then
            echo 'system-db:local' >> "$profile_file"
        elif [[ ! -f "$profile_file" ]]; then
            printf 'user-db:user\nsystem-db:local\n' > "$profile_file"
        fi
        dconf update
        log "PrivacyStrict" "Location services" "Disabled machine-wide"

        echo 'SUBSYSTEM=="video4linux", MODE="0600", OWNER="root", GROUP="root"' > "$udev_rule"
        udevadm control --reload-rules && udevadm trigger --subsystem-match=video4linux 2>/dev/null
        log "PrivacyStrict" "Camera devices" "Locked to root-only - THIS WILL BREAK Zoom/Teams/etc. until reverted"

        log "PrivacyStrict" "Microphone" "Not blocked - no safe machine-wide way to do this without disabling shared audio hardware (speakers use the same driver stack)"
        log "PrivacyStrict" "Cross-device clipboard sync" "N/A - Fedora GNOME has no built-in feature to disable; if KDE Connect is installed, turn it off there manually"
    fi
fi
#endregion

#region Automatic updates (dnf automatic)
if [[ $AUTO_UPDATE -eq 1 ]]; then
    auto_conf="/etc/dnf/automatic.conf"
    # Keeps the script's old name on purpose: it's how config written before the rename to
    # 05.Secure-Fedora.sh is still recognised (and safely removed on restore).
    auto_marker="# Managed by secure-fedora.sh - do not edit by hand"

    # dnf5 (Fedora 41+) names the timer dnf5-automatic.timer; dnf4 used
    # dnf-automatic.timer. Use whichever one is actually installed.
    find_auto_timer() {
        systemctl list-unit-files 'dnf5-automatic.timer' 'dnf-automatic.timer' 2>/dev/null \
            | awk '/automatic\.timer/{print $1}' | head -1
    }

    if [[ "$MODE" == "report" ]]; then
        timer=$(find_auto_timer)
        report_row "AutoUpdate" "Automatic update timer" "enabled" "$([[ -n "$timer" ]] && systemctl is-enabled "$timer" 2>/dev/null || echo not-installed)"
        apply=$(grep -oP '^\s*apply_updates\s*=\s*\K\w+' "$auto_conf" 2>/dev/null | tail -1)
        report_row "AutoUpdate" "apply_updates" "yes" "${apply:-no (default)}"
        utype=$(grep -oP '^\s*upgrade_type\s*=\s*\K\w+' "$auto_conf" 2>/dev/null | tail -1)
        report_row "AutoUpdate" "upgrade_type" "security" "${utype:-default}"
    elif [[ "$MODE" == "restore" ]]; then
        timer=$(find_auto_timer)
        [[ -n "$timer" ]] && systemctl disable --now "$timer" >/dev/null 2>&1
        if grep -qF "$auto_marker" "$auto_conf" 2>/dev/null; then
            rm -f "$auto_conf"
            [[ -f "$auto_conf.bak" ]] && mv "$auto_conf.bak" "$auto_conf"
        fi
        log "AutoUpdate" "Automatic update timer disabled, config removed" "Reverted to Fedora default (no automatic updates)"
    else
        if [[ -z "$(find_auto_timer)" ]]; then
            dnf install -y dnf5-plugin-automatic >/dev/null 2>&1 || dnf install -y dnf-automatic >/dev/null 2>&1
        fi
        timer=$(find_auto_timer)
        if [[ -z "$timer" ]]; then
            log "AutoUpdate" "Install automatic-update plugin" "FAILED - neither dnf5-plugin-automatic nor dnf-automatic could be installed"
        else
            if [[ -f "$auto_conf" ]] && ! grep -qF "$auto_marker" "$auto_conf"; then
                cp -p "$auto_conf" "$auto_conf.bak"
                log "AutoUpdate" "Existing $auto_conf" "Backed up to $auto_conf.bak before replacing"
            fi
            cat > "$auto_conf" <<EOF
$auto_marker
[commands]
upgrade_type = security
download_updates = yes
apply_updates = yes
reboot = never
EOF
            systemctl enable --now "$timer" >/dev/null 2>&1
            log "AutoUpdate" "Daily automatic security updates ($timer)" "Enabled - downloads and applies security updates, never reboots on its own"
        fi
    fi
fi
#endregion

#region Firefox
if [[ $FIREFOX -eq 1 || $FIREFOX_STRICT -eq 1 ]]; then
    firefox_policy_paths() {
        local paths=("/etc/firefox/policies/policies.json")
        local bin_dir
        bin_dir=$(rpm -ql firefox 2>/dev/null | grep -E '/firefox$' | head -1 | xargs dirname 2>/dev/null || true)
        [[ -n "$bin_dir" ]] && paths+=("$bin_dir/distribution/policies.json")
        printf '%s\n' "${paths[@]}"
    }

    ff_merge_policies() {
        # $1 = path to JSON literal file with the keys to merge under "policies"
        local newfile="$1" target
        while IFS= read -r target; do
            mkdir -p "$(dirname "$target")"
            python3 - "$target" "$newfile" <<'PYEOF'
import json, sys
target, newfile = sys.argv[1], sys.argv[2]
try:
    with open(target) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
data.setdefault("policies", {})
with open(newfile) as f:
    new_policies = json.load(f)
data["policies"].update(new_policies)
with open(target, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
        done < <(firefox_policy_paths)
    }

    ff_remove_keys() {
        # $1 = comma-separated top-level policy keys to remove
        local keys="$1" target
        while IFS= read -r target; do
            [[ -f "$target" ]] || continue
            python3 - "$target" "$keys" <<'PYEOF'
import json, sys
target, keys = sys.argv[1], sys.argv[2].split(",")
try:
    with open(target) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    sys.exit(0)
for k in keys:
    data.get("policies", {}).pop(k, None)
with open(target, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
        done < <(firefox_policy_paths)
    }

    ff_get_value() {
        # $1 = dotted key path e.g. "DisableTelemetry" or "Cookies.AcceptThirdParty"
        local key="$1" target
        while IFS= read -r target; do
            [[ -f "$target" ]] || continue
            val=$(python3 - "$target" "$key" <<'PYEOF'
import json, sys
target, key = sys.argv[1], sys.argv[2]
try:
    with open(target) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    print("")
    sys.exit(0)
node = data.get("policies", {})
for part in key.split("."):
    if not isinstance(node, dict) or part not in node:
        print("")
        sys.exit(0)
    node = node[part]
print(node if not isinstance(node, (dict, list)) else json.dumps(node))
PYEOF
)
            if [[ -n "$val" ]]; then echo "$val"; return; fi
        done < <(firefox_policy_paths)
        echo "not set"
    }
fi

if [[ $FIREFOX -eq 1 ]]; then
    ff_base_json="/tmp/secure-fedora-ff-base.$$.json"

    if [[ "$MODE" == "report" ]]; then
        report_row "Firefox" "DisableTelemetry" "True" "$(ff_get_value DisableTelemetry)"
        report_row "Firefox" "DisableFirefoxStudies" "True" "$(ff_get_value DisableFirefoxStudies)"
        report_row "Firefox" "DisablePocket" "True" "$(ff_get_value DisablePocket)"
        report_row "Firefox" "Cookies.AcceptThirdParty" "never" "$(ff_get_value Cookies.AcceptThirdParty)"
        report_row "Firefox" "NetworkPrediction" "False" "$(ff_get_value NetworkPrediction)"
        report_row "Firefox" "DNSOverHTTPS.Enabled" "True" "$(ff_get_value DNSOverHTTPS.Enabled)"
    elif [[ "$MODE" == "restore" ]]; then
        ff_remove_keys "DisableTelemetry,DisableFirefoxStudies,DisablePocket,Cookies,NetworkPrediction,DNSOverHTTPS,UserMessaging"
        log "Firefox" "Base policy keys removed" "Reverted - Firefox's own defaults apply again"
    else
        cat > "$ff_base_json" <<'EOF'
{
  "DisableTelemetry": true,
  "DisableFirefoxStudies": true,
  "DisablePocket": true,
  "Cookies": { "AcceptThirdParty": "never" },
  "NetworkPrediction": false,
  "DNSOverHTTPS": { "Enabled": true, "ProviderURL": "https://mozilla.cloudflare-dns.com/dns-query" },
  "UserMessaging": { "WhatsNew": false, "ExtensionRecommendations": false, "FeatureRecommendations": false }
}
EOF
        ff_merge_policies "$ff_base_json"
        rm -f "$ff_base_json"
        log "Firefox" "Telemetry/studies/Pocket off, third-party cookies blocked, prediction off, DoH on" "Applied - NOTE: DNS-over-HTTPS routes DNS through Cloudflare/Mozilla and can break split-horizon/internal DNS names on a homelab; review before keeping this on"
    fi
fi
#endregion

#region Firefox - strict (opt-in only)
if [[ $FIREFOX_STRICT -eq 1 ]]; then
    ff_strict_json="/tmp/secure-fedora-ff-strict.$$.json"

    if [[ "$MODE" == "report" ]]; then
        report_row "FirefoxStrict" "EnableTrackingProtection.Locked" "True" "$(ff_get_value EnableTrackingProtection.Locked)"
        report_row "FirefoxStrict" "DisableFirefoxAccounts" "True" "$(ff_get_value DisableFirefoxAccounts)"
        report_row "FirefoxStrict" "PasswordManagerEnabled" "False" "$(ff_get_value PasswordManagerEnabled)"
        report_row "FirefoxStrict" "SearchSuggestEnabled" "False" "$(ff_get_value SearchSuggestEnabled)"
        report_row "FirefoxStrict" "DisableSecurityBypass.InvalidCertificate" "True" "$(ff_get_value DisableSecurityBypass.InvalidCertificate)"
        report_row "FirefoxStrict" "DisableSecurityBypass.SafeBrowsing" "True" "$(ff_get_value DisableSecurityBypass.SafeBrowsing)"
        report_row "FirefoxStrict" "HttpsOnlyMode" "force_enabled" "$(ff_get_value HttpsOnlyMode)"
    elif [[ "$MODE" == "restore" ]]; then
        ff_remove_keys "EnableTrackingProtection,DisableFirefoxAccounts,PasswordManagerEnabled,OfferToSaveLogins,SearchSuggestEnabled,DisableSecurityBypass,HttpsOnlyMode"
        log "FirefoxStrict" "Strict policy keys removed" "Reverted - including HTTPS-Only mode"
    else
        cat > "$ff_strict_json" <<'EOF'
{
  "EnableTrackingProtection": { "Value": true, "Locked": true, "Cryptomining": true, "Fingerprinting": true },
  "DisableFirefoxAccounts": true,
  "PasswordManagerEnabled": false,
  "OfferToSaveLogins": false,
  "SearchSuggestEnabled": false,
  "DisableSecurityBypass": { "InvalidCertificate": true, "SafeBrowsing": true },
  "HttpsOnlyMode": "force_enabled"
}
EOF
        ff_merge_policies "$ff_strict_json"
        rm -f "$ff_strict_json"
        log "FirefoxStrict" "Strict tracking protection, sync/password manager/search-suggest off, cert-bypass blocked, HTTPS-Only forced" "Applied - HTTPS-Only mode WILL break any plain-HTTP intranet/homelab page you browse to"
    fi
fi
#endregion

#region Sysmon for Linux
if [[ $SYSMON -eq 1 ]]; then
    sysmon_repo_rpm_url="https://packages.microsoft.com/config/fedora/$(rpm -E %fedora 2>/dev/null || echo 39)/packages-microsoft-prod.rpm"
    sysmon_config_url="https://raw.githubusercontent.com/microsoft/MSTIC-Sysmon/main/linux/configs/main.xml"
    sysmon_config_path="/etc/sysmon/main.xml"

    find_sysmon_service() {
        systemctl list-unit-files 2>/dev/null | awk '/^sysmon/{print $1}' | head -1
    }

    if [[ "$MODE" == "report" ]]; then
        svc=$(find_sysmon_service)
        if [[ -n "$svc" ]]; then
            report_row "Sysmon" "Service status" "active" "$(systemctl is-active "$svc" 2>/dev/null)"
        else
            report_row "Sysmon" "Service status" "active" "not-installed"
        fi
        echo "[Sysmon] Note: applied config content isn't diffed - only install/service state is checked."
    elif [[ "$MODE" == "restore" ]]; then
        svc=$(find_sysmon_service)
        if [[ -z "$svc" ]]; then
            log "Sysmon" "Uninstall" "Not installed - nothing to do"
        else
            sysmon_bin=$(command -v sysmon || command -v sysmonforlinux || echo "")
            if [[ -n "$sysmon_bin" ]]; then
                "$sysmon_bin" -u force >/dev/null 2>&1
                log "Sysmon" "Uninstall" "Removed (no Sysmon is the Fedora default)"
            else
                log "Sysmon" "Uninstall" "Service found but binary not located - remove manually"
            fi
        fi
    else
        if ! rpm -q packages-microsoft-prod >/dev/null 2>&1; then
            echo "[Sysmon] Registering Microsoft's package repo..."
            rpm -Uvh "$sysmon_repo_rpm_url" >/dev/null 2>&1
        fi
        echo "[Sysmon] Installing sysmonforlinux..."
        dnf install -y sysmonforlinux >/dev/null 2>&1

        sysmon_bin=$(command -v sysmon || command -v sysmonforlinux || echo "")
        if [[ -z "$sysmon_bin" ]]; then
            log "Sysmon" "Install" "FAILED - package installed but binary not found on PATH; review the repo/package manually"
        else
            mkdir -p "$(dirname "$sysmon_config_path")"
            echo "[Sysmon] Downloading MSTIC-Sysmon baseline config..."
            if curl -fsSL "$sysmon_config_url" -o "$sysmon_config_path"; then
                svc=$(find_sysmon_service)
                if [[ -n "$svc" ]]; then
                    "$sysmon_bin" -c "$sysmon_config_path" >/dev/null 2>&1
                    log "Sysmon" "Update configuration" "Applied MSTIC-Sysmon baseline config to existing install"
                else
                    "$sysmon_bin" -accepteula -i "$sysmon_config_path" >/dev/null 2>&1
                    log "Sysmon" "Install" "Installed with MSTIC-Sysmon baseline config"
                fi
            else
                log "Sysmon" "Download config" "FAILED - check network access / verify $sysmon_config_url manually"
            fi
        fi
    fi
fi
#endregion

#region dnf updates
if [[ $DNF_UPDATE -eq 1 ]]; then
    if [[ "$MODE" == "restore" ]]; then
        log "DnfUpdate" "Restore defaults" "N/A - installing updates has no default to revert to, skipped"
    elif [[ "$MODE" == "report" ]]; then
        echo "[DnfUpdate] Checking for pending updates - this can take a minute..."
        count=$(dnf check-update -q 2>/dev/null | grep -cE '^\S+\.\S+\s+\S+\s+\S+' || true)
        report_row "DnfUpdate" "Pending package updates" "0" "$count"
    else
        echo "[DnfUpdate] Running dnf upgrade..."
        if dnf upgrade -y; then
            reboot_note="no reboot needed"
            if command -v needs-restarting >/dev/null 2>&1 && ! needs-restarting -r >/dev/null 2>&1; then
                reboot_note="REBOOT REQUIRED"
            fi
            log "DnfUpdate" "System packages upgraded" "$reboot_note"
        else
            log "DnfUpdate" "dnf upgrade" "FAILED - see output above"
        fi
    fi
fi
#endregion

#region Flatpak updates
if [[ $FLATPAK_UPDATE -eq 1 ]]; then
    if [[ "$MODE" == "restore" ]]; then
        log "FlatpakUpdate" "Restore defaults" "N/A - installing updates has no default to revert to, skipped"
    elif ! command -v flatpak >/dev/null 2>&1; then
        if [[ "$MODE" == "report" ]]; then
            report_row "FlatpakUpdate" "Pending updates" "0" "flatpak not installed"
        else
            log "FlatpakUpdate" "Upgrade all" "Skipped - flatpak not installed"
        fi
    elif [[ "$MODE" == "report" ]]; then
        count=$(flatpak remote-ls --updates 2>/dev/null | grep -c . || true)
        report_row "FlatpakUpdate" "Pending updates" "0" "$count"
    else
        echo "[FlatpakUpdate] Updating flatpak apps..."
        flatpak update -y >/dev/null 2>&1
        log "FlatpakUpdate" "Upgrade all" "Done"
    fi
fi
#endregion

#region Separate admin account (opt-in, always last - see the header for the safety checks)
if [[ $SEPARATE_ADMIN -eq 1 ]]; then
    demote_user="${DEMOTE_USER:-${SUDO_USER:-}}"

    in_wheel() { id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx wheel; }
    user_exists() { id "$1" >/dev/null 2>&1; }

    if [[ -z "$demote_user" || "$demote_user" == "root" ]]; then
        log "SeparateAdmin" "$MODE" "Skipped - couldn't tell which account to use; run this with sudo from that account, or pass --demote-user NAME"
    elif [[ "$MODE" == "report" ]]; then
        report_row "SeparateAdmin" "'$demote_user' is an administrator (wheel)" "no" "$(in_wheel "$demote_user" && echo yes || echo no)"
        if [[ -n "$NEW_ADMIN" ]]; then
            report_row "SeparateAdmin" "Separate admin account '$NEW_ADMIN'" "yes" "$(user_exists "$NEW_ADMIN" && in_wheel "$NEW_ADMIN" && echo yes || echo no)"
        else
            others=$(getent group wheel | cut -d: -f4 | tr ',' '\n' | grep -vx "$demote_user" | grep -v '^$' | paste -sd, -)
            report_row "SeparateAdmin" "Separate admin account exists (${others:-none})" "yes" "$([[ -n "$others" ]] && echo yes || echo no)"
        fi
    elif [[ "$MODE" == "restore" ]]; then
        if in_wheel "$demote_user"; then
            log "SeparateAdmin" "'$demote_user' admin rights" "Already in wheel - nothing to do"
        else
            usermod -aG wheel "$demote_user"
            log "SeparateAdmin" "'$demote_user' admin rights" "$(in_wheel "$demote_user" && echo "Restored (log out and back in to pick it up)" || echo "FAILED - check 'id $demote_user'")"
        fi
        log "SeparateAdmin" "Admin account" "Left in place - deleting accounts isn't offered; remove it with 'userdel -r NAME' if you no longer need it"
    else
        new_admin="$NEW_ADMIN"
        [[ -z "$new_admin" ]] && read -rp "Name for the new admin account (e.g. localadmin): " new_admin

        if [[ ! "$new_admin" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
            log "SeparateAdmin" "Harden" "Skipped - '$new_admin' isn't a valid user name (lowercase letters, digits, _ or -, starting with a letter)"
        elif [[ "$new_admin" == "$demote_user" || "$new_admin" == "root" ]]; then
            log "SeparateAdmin" "Harden" "Skipped - the new admin account can't be '$new_admin'"
        else
            echo
            echo "This will $(user_exists "$new_admin" && echo reuse || echo create) the admin account '$new_admin', then remove '$demote_user' from wheel."
            echo "Afterwards '$demote_user' can't use sudo or approve admin prompts - you'll use '$new_admin' and its password instead."
            read -rp "Type YES to continue: " confirm
            ok=1
            if [[ "$confirm" != "YES" ]]; then
                log "SeparateAdmin" "Harden" "Cancelled - nothing changed"
                ok=0
            elif user_exists "$new_admin"; then
                if in_wheel "$new_admin"; then
                    log "SeparateAdmin" "Admin account '$new_admin'" "Already exists - reusing it"
                else
                    log "SeparateAdmin" "Harden" "Stopped - '$new_admin' already exists but isn't in wheel; pick another name"
                    ok=0
                fi
            else
                useradd -m -G wheel -c "Administrator" "$new_admin"
                echo "Set the password for '$new_admin':"
                if passwd "$new_admin"; then
                    log "SeparateAdmin" "Admin account '$new_admin'" "Created"
                else
                    userdel -r "$new_admin" >/dev/null 2>&1
                    log "SeparateAdmin" "Harden" "Stopped - setting the password failed, so '$new_admin' was removed again; '$demote_user' left unchanged"
                    ok=0
                fi
            fi

            if [[ $ok -eq 1 ]]; then
                pw_state=$(passwd -S "$new_admin" 2>/dev/null | awk '{print $2}')
                if ! in_wheel "$new_admin"; then
                    log "SeparateAdmin" "Harden" "Stopped - '$new_admin' isn't in wheel; '$demote_user' left unchanged"
                elif [[ "$pw_state" != "P" && "$pw_state" != "PS" ]]; then
                    log "SeparateAdmin" "Harden" "Stopped - '$new_admin' has no usable password (passwd -S: ${pw_state:-unknown}); '$demote_user' left unchanged"
                elif ! sudo -l -U "$new_admin" 2>/dev/null | grep -qE '\(ALL( : ALL)?\) ALL'; then
                    log "SeparateAdmin" "Harden" "Stopped - sudo doesn't grant '$new_admin' full rights (is '%wheel ALL=(ALL) ALL' in sudoers?); '$demote_user' left unchanged"
                elif ! in_wheel "$demote_user"; then
                    log "SeparateAdmin" "'$demote_user' admin rights" "Already a standard user"
                else
                    gpasswd -d "$demote_user" wheel >/dev/null
                    if in_wheel "$demote_user"; then
                        log "SeparateAdmin" "'$demote_user' admin rights" "FAILED - still in wheel"
                    else
                        log "SeparateAdmin" "'$demote_user' admin rights" "Removed from wheel - log out and back in to finish; use '$new_admin' for admin tasks"
                    fi
                fi
            fi
        fi
    fi
fi
#endregion

#region Summary
if [[ "$MODE" == "report" ]]; then
    if [[ ${#REPORT_ROWS[@]} -gt 0 ]]; then
        echo
        echo "=== Report: Expected vs Found ==="
        {
            printf 'Category\tSetting\tExpected\tFound\tStatus\n'
            printf '%s\n' "${REPORT_ROWS[@]}"
        } | column -t -s $'\t'

        mismatches=0
        for row in "${REPORT_ROWS[@]}"; do
            IFS=$'\t' read -r cat setting expected found status <<< "$row"
            if [[ "$status" == "MISMATCH" ]]; then
                mismatches=$((mismatches + 1))
                echo " - [$cat] $setting: expected '$expected', found '$found'"
            fi
        done
        echo
        if [[ $mismatches -gt 0 ]]; then
            echo "$mismatches setting(s) do not match the hardened baseline."
        else
            echo "All checked settings match the hardened baseline."
        fi
    fi
elif [[ ${#RESULTS[@]} -gt 0 ]]; then
    echo
    echo "=== Summary ($MODE) ==="
    {
        printf 'Category\tAction\tStatus\n'
        printf '%s\n' "${RESULTS[@]}"
    } | column -t -s $'\t'
    if [[ "$MODE" == "harden" ]]; then
        echo "Some changes (SELinux mode flip, sysctl reloads, SELinux/SSH/sudo) may need a review or reboot to take full effect."
    else
        echo "Some reverts (service restarts, dconf/sysctl reloads) may take a moment or need a reboot to fully apply."
    fi
fi
#endregion
