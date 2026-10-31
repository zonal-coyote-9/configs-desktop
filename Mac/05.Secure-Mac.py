#!/usr/bin/env python3
"""Applies reasonable, reversible security hardening to a Mac - or reverts
any of the same categories back to macOS out-of-box defaults - or reports
Expected vs Found state for every setting it manages. This is the macOS
counterpart to 05.Secure-Windows.ps1 and 05.Secure-Fedora.sh, mirroring their
category concept and three modes (harden / --restore-defaults / --report)
as closely as macOS allows.

Every category is written to be idempotent - safe to re-run. Unlike the
Windows/Fedora scripts, this one does NOT need to be launched as root -
each command that needs elevation calls 'sudo' itself. You're asked for
your password once at the start; sudo's cache is kept fresh in the
background for the rest of the run, so it never stops to prompt again.
Run with no options to show this help - nothing changes until you pick
--all or at least one category.

SCOPE NOTE: several categories present in the Windows/Fedora scripts have
no safe macOS equivalent and are intentionally left out rather than
guessed at:
  - Deep privacy controls (force-blocking camera/mic, disabling location
    services, Recall-style snapshot blocking) are gated behind TCC and
    System Integrity Protection on modern macOS and are no longer
    scriptable via 'defaults' - Apple locked this down specifically to
    prevent tools like this one from doing it silently.
  - mDNS/Bonjour (the LLMNR/NetBIOS analogue) is SIP-protected and can't
    be disabled without disabling SIP, which this script won't do.
  - There's no direct UAC analogue - macOS already requires
    authentication for admin actions at the OS level. --sudo covers the
    sudo side the same way the Fedora script does, minus the always-
    re-prompt timeout (see --sudo below).
  - Installing pending OS/package updates is 04.Update-Mac.py's job, not
    this script's - --software-update here only verifies the
    auto-update *policy* is on.

CATEGORIES
  --firewall
      Harden: Application Firewall on, stealth mode on, blocked-connection
      logging on.
      Restore: all three off (macOS's out-of-box default - the
      Application Firewall is OFF on a fresh Mac).

  --filevault
      Harden: enables FileVault (disk encryption) if not already on. This
      prompts for your account password and prints a personal recovery
      key - save it somewhere safe.
      Restore: DECRYPTS the startup disk. This can take hours and leaves
      the disk unprotected - the script warns and pauses before doing it.

  --gatekeeper
      Harden: ensures Gatekeeper (app notarization/assessment checks) is
      enabled, and that download quarantine (LSQuarantine - the "downloaded
      from the internet" check, macOS's equivalent of Windows'
      Mark-of-the-Web) is on.
      Restore: Gatekeeper left enabled - already macOS's stock default;
      disabling it isn't offered by this script. The LSQuarantine override
      is removed (macOS default: on).

  --sip
      Report/verify only - reports whether System Integrity Protection is
      enabled. SIP can't be toggled from a running system (it requires
      booting into Recovery Mode and running 'csrutil enable/disable'
      there), so harden mode just reports the same finding with
      instructions if it's off, and restore is a no-op.

  --ssh
      Harden: disables Remote Login (sshd) entirely, OR with --keep-ssh,
      leaves it enabled but applies a hardened sshd drop-in at
      /etc/ssh/sshd_config.d/000-hardening.conf (root login off, empty
      passwords off, X11 forwarding off, lower MaxAuthTries, idle client
      timeout, and password auth disabled UNLESS --keep-password-auth is
      given or no user on the system has an authorized_keys file, in which
      case password auth is left alone so you can't lock yourself out).
      Restore: hardening drop-in removed, Remote Login disabled (macOS
      default).

  --keep-ssh
      Modifier for --ssh: keep Remote Login enabled but hardened, instead
      of disabling it. Ignored in --restore-defaults mode.

  --keep-password-auth
      Modifier for --ssh --keep-ssh: keep SSH password authentication
      enabled, but still apply every other SSH hardening item. Same as the
      Fedora script's flag. Ignored in --restore-defaults mode.

  --sharing
      Harden: disables File Sharing (SMB) and Screen Sharing (stops them
      if running and prevents them from starting), and turns off Remote
      Apple Events.
      Restore: left disabled/off - already macOS's stock state on a fresh
      install, so there's nothing more permissive to revert to.

  --lockscreen
      Harden: requires a password immediately on wake/screensaver, sets a
      10-minute idle lock timeout, and disables automatic login if it was
      configured.
      Restore: password-on-wake and idle timeout settings removed
      (unconfigured, macOS default). Automatic login is left disabled -
      re-enabling passwordless login isn't offered by this script.

  --sudo
      Harden: sudo credential cache scoped per terminal (timestamp_type=tty),
      sessions run through a pty, 3 password tries, and every sudo action
      logged to /var/log/sudo.log - via a visudo-checked drop-in in
      /etc/sudoers.d, same as the Fedora script. Unlike Fedora, the cache
      timeout is NOT set to 0: the Mac scripts ask for your password once
      and rely on sudo's cache for the rest of the run, which a zero timeout
      would break (every step would prompt again).
      Restore: drop-in removed, back to macOS's stock sudoers.

  --audit
      Harden/report only: verifies macOS's built-in audit daemon (auditd)
      is running and reports its configured flags. Doesn't edit
      /etc/security/audit_control - macOS ships a reasonable flag set by
      default already, and a bad edit can silently break the audit trail.
      Restore: no-op, for the same reason.

  --credential-hardening
      Harden: disables the Guest account if it's on, and adds a global
      password policy matching the Windows/Fedora scripts: 14-character
      minimum, at least 3 of 4 character types (lowercase, uppercase,
      digits, symbols), and a 15-minute lockout after 10 failed attempts.
      Applied with 'pwpolicy -setaccountpolicies', merged into whatever
      policy is already there (only this script's three rules are added or
      replaced). Length/complexity are checked the next time a password is
      changed - existing passwords keep working.
      Restore: this script's three rules removed, leaving macOS's own
      stock policy (4-character minimum, no lockout). Guest account left
      disabled - already macOS's default.

  --privacy
      Harden: turns off sharing Mac Analytics (diagnostic/usage data) with
      Apple and with app developers - the counterpart to Windows'
      diagnostic data level and Fedora's ABRT reporting - silences the
      crash reporter dialog, and disables personalized Apple Advertising.
      Restore: all settings removed (unconfigured), macOS defaults apply.

  --software-update
      Harden: turns on automatic update checking/downloading/installing
      in Software Update preferences (same keys 02.Configure-Mac.py sets -
      re-asserted here so a regression shows up in --report). Does NOT
      install anything pending; run 04.Update-Mac.py for that.
      Restore: settings removed (unconfigured), macOS defaults apply.

  --edge
      Skipped entirely (with a message) if Microsoft Edge isn't installed
      (/Applications/Microsoft Edge.app not found).
      Harden: the same policy set as the Windows script - SmartScreen
      (site + PUA + trusted-download checks), third-party cookies
      blocked, Balanced tracking prevention, password leak detection on,
      credit card autofill off, network prediction off, alternate error
      pages off, shopping assistant off, personalization reporting off,
      feedback prompts off, Do Not Track sent, diagnostic/usage reporting
      off, Enhance Security Mode Balanced, startup boost off.
      Restore: all of the above policy keys removed, Edge's own defaults
      apply again.
      MECHANISM/CAVEAT: Edge is Chromium-based and reads managed policy
      from a plist at
      "/Library/Managed Preferences/<you>/com.microsoft.Edge.plist" -
      the same mechanism Chrome/Edge enterprise MDM deployments use, but
      applied here as a plain file instead of a real MDM profile. This is
      a well-documented way to test Chromium policies locally without
      MDM, but it's best-effort: fully quit and relaunch Edge after
      running this, then check edge://policy to confirm each policy
      shows as applied.

  --edge-strict
      NOT included in --all - opt in explicitly. Skipped if Edge isn't
      installed, same as --edge.
      Harden: escalates tracking prevention and Enhance Security Mode to
      Strict, disables sign-in/sync and the built-in password manager, disables
      search-suggest, blocks bypassing SSL certificate warnings, and
      forces HTTPS-Only mode. HTTPS-Only mode WILL break any plain-HTTP
      intranet/homelab page you browse to until reverted.
      Restore: all of the above removed, including HTTPS-Only mode.

  --separate-admin
      NOT included in --all - opt in explicitly. Always runs last.
      Harden: creates a separate local admin account (--new-admin NAME, or
      you're asked for one), then removes the current user (or
      --demote-user NAME) from the admin group, so day-to-day work happens
      in a standard account and admin actions need the other account's
      name and password. Safety checks, in order - any failure stops
      BEFORE your account is demoted:
        1. you type YES to confirm the plan;
        2. the new account is created by sysadminctl, which prompts for its
           password (and for yours, to grant it a Secure Token - see below);
        3. it must exist and be in the admin group;
        4. you type its password again and it must authenticate
           (dscl -authonly) - this catches a mistyped password;
        5. if your account has a Secure Token (Apple Silicon and FileVault
           Macs), the new admin must have one too, or it couldn't install
           macOS updates or unlock the disk at startup.
      If the admin account already exists it's reused (checks 3-5 still
      apply). Afterwards sudo no longer works from the demoted account;
      macOS asks for the admin account's credentials instead.
      Report: shows whether the user is an admin, and whether a separate
      admin account exists.
      Restore: adds --demote-user back to the admin group. Run it while
      logged in as the admin account, e.g.
      ./05.Secure-Mac.py --separate-admin --demote-user alice --restore-defaults
      The admin account is left in place - deleting accounts isn't offered.

  --new-admin NAME
      Modifier for --separate-admin: short name of the admin account to
      create or reuse.

  --demote-user NAME
      Modifier for --separate-admin: the account to remove from (or, on
      restore, add back to) the admin group. Default: the current user.

  --all
      Runs every category above EXCEPT --edge-strict and --separate-admin,
      which are opt-in only.

  --restore-defaults
      Reverts the selected categories to macOS out-of-box defaults
      instead of hardening them. Cannot be combined with --report.

  --report
      For each selected category, prints a table with one row per
      setting: Category, Setting, Expected, Found, Status (OK/MISMATCH).
      Makes no changes. Cannot be combined with --restore-defaults.

EXAMPLES
  ./05.Secure-Mac.py --all
  ./05.Secure-Mac.py --firewall --filevault --gatekeeper --ssh
  ./05.Secure-Mac.py --all --report
  ./05.Secure-Mac.py --ssh --keep-ssh
  ./05.Secure-Mac.py --ssh --keep-ssh --keep-password-auth
  ./05.Secure-Mac.py --ssh --lockscreen --restore-defaults
  ./05.Secure-Mac.py --edge --edge-strict --report
  ./05.Secure-Mac.py --separate-admin --new-admin localadmin
"""

import argparse
import getpass
import os
import plistlib
import re
import subprocess
import sys
import tempfile
import threading
import time
from dataclasses import dataclass, field
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


# Older versions of this script appended a marked block to sshd_config itself; it's
# still stripped on every run so upgraded machines don't end up with both.
SSH_MARK_BEGIN = "# BEGIN 05.Secure-Mac.py hardening - do not edit by hand"
SSH_MARK_END = "# END 05.Secure-Mac.py hardening"
# sshd keeps the FIRST value it reads for each keyword, and sshd_config pulls in
# sshd_config.d/* near the top - a drop-in that sorts first wins over anything
# later in the main file or in Apple's own 100-macos.conf.
SSH_DROP_IN = Path("/etc/ssh/sshd_config.d/000-hardening.conf")
SUDOERS_DROP_IN = "/etc/sudoers.d/99-hardening"

RESULTS = []
REPORT = []


@dataclass
class LogEntry:
    category: str
    action: str
    status: str


@dataclass
class ReportRow:
    category: str
    setting: str
    expected: str
    found: str
    status: str = field(init=False)

    def __post_init__(self):
        self.status = "OK" if str(self.expected) == str(self.found) else "MISMATCH"


def log(category, action, status):
    RESULTS.append(LogEntry(category, action, status))
    print(f"[{category}] {action} -> {status}")


def report_row(category, setting, expected, found):
    REPORT.append(ReportRow(category, setting, expected, found))


def sh(cmd, input_text=None):
    """Run a command for its output; never raises. Returns (returncode, stdout, stderr)."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, input=input_text)
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except FileNotFoundError:
        return 127, "", f"{cmd[0]}: not found"


def run(cmd, input_text=None):
    """Run a state-changing command; warns but never raises on failure."""
    try:
        result = subprocess.run(cmd, input=input_text, text=True if input_text is not None else None)
    except FileNotFoundError:
        print(f"Warning: {cmd[0]} not found, skipping")
        return
    if result.returncode != 0:
        print(f"Warning: {' '.join(cmd)} exited with status {result.returncode}")


def print_table(rows, headers):
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))

    def fmt(cells):
        return "  ".join(str(c).ljust(w) for c, w in zip(cells, widths))

    print(fmt(headers))
    print(fmt(["-" * w for w in widths]))
    for row in rows:
        print(fmt(row))


# ---------------------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------------------

def category_firewall(mode):
    cat = "Firewall"
    fw = "/usr/libexec/ApplicationFirewall/socketfilterfw"

    def is_on(flag, word="enabled"):
        _, out, _ = sh(["sudo", fw, flag])
        return word in out.lower()

    if mode == "report":
        report_row(cat, "Application Firewall", "enabled",
                    "enabled" if is_on("--getglobalstate") else "disabled")
        report_row(cat, "Stealth mode", "enabled",
                    "enabled" if is_on("--getstealthmode") else "disabled")
        report_row(cat, "Blocked-connection logging", "on",
                    "on" if is_on("--getloggingmode", "on") else "off")
    elif mode == "restore":
        run(["sudo", fw, "--setglobalstate", "off"])
        run(["sudo", fw, "--setstealthmode", "off"])
        run(["sudo", fw, "--setloggingmode", "off"])
        log(cat, "Firewall/stealth/logging", "Reverted to macOS default (all off)")
    else:
        run(["sudo", fw, "--setglobalstate", "on"])
        run(["sudo", fw, "--setstealthmode", "on"])
        run(["sudo", fw, "--setloggingmode", "on"])
        log(cat, "Application Firewall enabled, stealth mode on, logging on", "Done")


# ---------------------------------------------------------------------------
# FileVault
# ---------------------------------------------------------------------------

def category_filevault(mode):
    cat = "FileVault"
    _, status_out, _ = sh(["fdesetup", "status"])
    is_on = "FileVault is On" in status_out

    if mode == "report":
        report_row(cat, "FileVault enabled", "On", "On" if is_on else "Off")
    elif mode == "restore":
        if not is_on:
            log(cat, "Disable", "Already off / not encrypted")
        else:
            print("WARNING: about to DECRYPT the startup disk. It will be unprotected once this "
                  "completes, and decryption can take hours. Ctrl+C now to cancel.")
            time.sleep(5)
            run(["sudo", "fdesetup", "disable"])
            log(cat, "Disable", "Decryption started - check 'fdesetup status' for progress")
    else:
        if is_on:
            log(cat, "Enable", "Already enabled")
        else:
            print("Enabling FileVault - you'll be prompted for your account password, and a "
                  "personal recovery key will be printed. SAVE THE RECOVERY KEY somewhere safe "
                  "(e.g. a password manager) - it's the only way in if you forget your password.")
            run(["sudo", "fdesetup", "enable"])
            log(cat, "Enable", "Enabled - back up the recovery key if you haven't already")


# ---------------------------------------------------------------------------
# Gatekeeper
# ---------------------------------------------------------------------------

def category_gatekeeper(mode):
    cat = "Gatekeeper"
    _, out, _ = sh(["spctl", "--status"])
    is_enabled = "assessments enabled" in out.lower()

    quarantine = _defaults_read("com.apple.LaunchServices", "LSQuarantine")

    if mode == "report":
        report_row(cat, "Gatekeeper", "enabled", "enabled" if is_enabled else "disabled")
        report_row(cat, "Download quarantine (LSQuarantine)", "on",
                    "off" if quarantine == "0" else "on")
    elif mode == "restore":
        log(cat, "Restore", "Left enabled - already macOS's stock default; disabling "
                             "notarization checks isn't offered by this script")
        sh(["defaults", "delete", "com.apple.LaunchServices", "LSQuarantine"])
        log(cat, "Download quarantine", "Override removed (macOS default: on)")
    else:
        if is_enabled:
            log(cat, "Gatekeeper", "Already enabled")
        else:
            run(["sudo", "spctl", "--master-enable"])
            log(cat, "Gatekeeper", "Enabled")
        run(["defaults", "write", "com.apple.LaunchServices", "LSQuarantine", "-bool", "true"])
        log(cat, "Download quarantine (LSQuarantine)", "On")


# ---------------------------------------------------------------------------
# SIP (report/status only - can't be toggled from a running system)
# ---------------------------------------------------------------------------

def category_sip(mode):
    cat = "SIP"
    _, out, _ = sh(["csrutil", "status"])
    is_enabled = "enabled" in out.lower()

    if mode == "report":
        report_row(cat, "System Integrity Protection", "enabled",
                    "enabled" if is_enabled else "disabled")
    elif mode == "restore":
        log(cat, "Restore", "No-op - SIP can only be toggled by booting into Recovery Mode and "
                             "running 'csrutil enable'/'csrutil disable' there; not scriptable "
                             "from a running system")
    else:
        if is_enabled:
            log(cat, "System Integrity Protection", "Already enabled")
        else:
            log(cat, "System Integrity Protection", "DISABLED - this can't be fixed from a "
                "running system. Reboot into Recovery Mode (hold the power button on Apple "
                "Silicon, or Cmd+R on Intel during startup), open Terminal from Utilities, and "
                "run 'csrutil enable'")


# ---------------------------------------------------------------------------
# SSH (Remote Login)
# ---------------------------------------------------------------------------

def _remote_login_state():
    _, out, _ = sh(["sudo", "systemsetup", "-getremotelogin"])
    return "on" if "on" in out.lower() else "off"


def _strip_ssh_block(text):
    lines, out, skipping = text.splitlines(), [], False
    for line in lines:
        if line.strip() == SSH_MARK_BEGIN:
            skipping = True
            continue
        if line.strip() == SSH_MARK_END:
            skipping = False
            continue
        if not skipping:
            out.append(line)
    return "\n".join(out) + ("\n" if out else "")


def _any_authorized_keys():
    # Real user accounts on modern macOS live in Open Directory, not /etc/passwd (which
    # typically has zero entries with a /Users home dir) - enumerate via dscl instead.
    _, out, _ = sh(["dscl", ".", "-list", "/Users", "NFSHomeDirectory"])
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 2 or not parts[-1].startswith("/Users/"):
            continue
        keys_file = Path(parts[-1]) / ".ssh" / "authorized_keys"
        if keys_file.is_file() and keys_file.stat().st_size > 0:
            return True
    return False


def _strip_legacy_ssh_block(config):
    if config.exists() and SSH_MARK_BEGIN in config.read_text():
        run(["sudo", "tee", str(config)], input_text=_strip_ssh_block(config.read_text()))
        return True
    return False


def category_ssh(mode, keep_ssh, keep_password_auth):
    cat = "SSH"
    config = Path("/etc/ssh/sshd_config")

    if mode == "report":
        state = _remote_login_state()
        report_row(cat, "Remote Login (sshd)", "on" if keep_ssh else "off", state)
        if keep_ssh:
            report_row(cat, "Hardening drop-in present", "yes", "yes" if SSH_DROP_IN.exists() else "no")
    elif mode == "restore":
        legacy = _strip_legacy_ssh_block(config)
        if SSH_DROP_IN.exists() or legacy:
            run(["sudo", "rm", "-f", str(SSH_DROP_IN)])
            run(["sudo", "launchctl", "kickstart", "-k", "system/com.openssh.sshd"])
        run(["sudo", "systemsetup", "-setremotelogin", "off"])
        log(cat, "Restore", "Hardening drop-in removed, Remote Login disabled (macOS default)")
    else:
        if not keep_ssh:
            run(["sudo", "systemsetup", "-setremotelogin", "off"])
            log(cat, "Remote Login disabled", "Done")
            return

        run(["sudo", "systemsetup", "-setremotelogin", "on"])

        block_lines = [
            "# Managed by 05.Secure-Mac.py - do not edit by hand",
            "PermitRootLogin no",
            "PermitEmptyPasswords no",
            "X11Forwarding no",
            "MaxAuthTries 4",
            "ClientAliveInterval 300",
            "ClientAliveCountMax 2",
        ]
        if keep_password_auth:
            block_lines.append("PasswordAuthentication yes")
            pw_note = "password auth kept enabled"
        elif _any_authorized_keys():
            block_lines.append("PasswordAuthentication no")
            pw_note = "password auth disabled (key-based only)"
        else:
            block_lines.append(
                "# PasswordAuthentication left at its configured value - no authorized_keys "
                "file was found for any user, so disabling password auth was skipped to avoid "
                "lockout."
            )
            pw_note = "password auth left enabled - no authorized_keys found for any user"

        _strip_legacy_ssh_block(config)
        run(["sudo", "tee", str(SSH_DROP_IN)], input_text="\n".join(block_lines) + "\n")
        run(["sudo", "launchctl", "kickstart", "-k", "system/com.openssh.sshd"])
        log(cat, f"Remote Login kept enabled, hardened ({pw_note})", "Done")


# ---------------------------------------------------------------------------
# Sharing
# ---------------------------------------------------------------------------

def _remote_apple_events_state():
    _, out, _ = sh(["sudo", "systemsetup", "-getremoteappleevents"])
    return "on" if "on" in out.lower() else "off"


def category_sharing(mode):
    cat = "Sharing"
    services = {
        "system/com.apple.smbd": "File Sharing (SMB)",
        "system/com.apple.screensharing": "Screen Sharing",
    }

    if mode == "report":
        _, listing, _ = sh(["launchctl", "list"])
        running = {line.split()[-1] for line in listing.splitlines() if line.strip()}
        for target, name in services.items():
            label = target.split("/", 1)[1]
            report_row(cat, name, "not running", "running" if label in running else "not running")
        report_row(cat, "Remote Apple Events", "off", _remote_apple_events_state())
    elif mode == "restore":
        log(cat, "File Sharing / Screen Sharing / Remote Apple Events",
            "Left disabled - already macOS's stock state on a fresh install")
    else:
        for target, name in services.items():
            run(["sudo", "launchctl", "disable", target])
            sh(["sudo", "launchctl", "bootout", target])  # stop it now if it was running
        log(cat, "File Sharing (SMB) and Screen Sharing disabled", "Done")

        run(["sudo", "systemsetup", "-setremoteappleevents", "off"])
        log(cat, "Remote Apple Events", "Disabled")


# ---------------------------------------------------------------------------
# Sudo (see the --sudo docstring entry for why timestamp_timeout isn't 0)
# ---------------------------------------------------------------------------

SUDOERS_LINES = [
    "# Managed by 05.Secure-Mac.py - do not edit by hand",
    "Defaults timestamp_type=tty",
    "Defaults use_pty",
    "Defaults passwd_tries=3",
    'Defaults logfile="/var/log/sudo.log"',
]


def category_sudo(mode):
    cat = "Sudo"

    if mode == "report":
        rc, content, _ = sh(["sudo", "cat", SUDOERS_DROP_IN])
        if rc != 0:
            report_row(cat, "Hardening drop-in present", "yes", "no")
            return
        report_row(cat, "timestamp_type", "tty", "tty" if "timestamp_type=tty" in content else "unset")
        report_row(cat, "use_pty", "set", "set" if "use_pty" in content else "unset")
        report_row(cat, "logfile", "/var/log/sudo.log",
                    "/var/log/sudo.log" if 'logfile="/var/log/sudo.log"' in content else "unset")
    elif mode == "restore":
        run(["sudo", "rm", "-f", SUDOERS_DROP_IN])
        log(cat, "Hardening drop-in removed", "Reverted to macOS stock sudo defaults")
    else:
        with tempfile.NamedTemporaryFile("w", suffix=".sudoers", delete=False) as tmp:
            tmp.write("\n".join(SUDOERS_LINES) + "\n")
        try:
            rc, _, err = sh(["sudo", "visudo", "-cf", tmp.name])
            if rc != 0:
                log(cat, "Harden", f"FAILED visudo syntax check, nothing applied: {err}")
                return
            run(["sudo", "install", "-m", "0440", "-o", "root", "-g", "wheel", tmp.name, SUDOERS_DROP_IN])
        finally:
            Path(tmp.name).unlink(missing_ok=True)
        log(cat, "Per-terminal credential cache, pty required, actions logged to /var/log/sudo.log", "Done")


# ---------------------------------------------------------------------------
# Lockscreen
# ---------------------------------------------------------------------------

def _defaults_read(domain, key, current_host=False):
    cmd = ["defaults"]
    if current_host:
        cmd.append("-currentHost")
    cmd += ["read", domain, key]
    rc, out, _ = sh(cmd)
    return out if rc == 0 else "not set"


def category_lockscreen(mode):
    cat = "Lockscreen"
    idle_seconds = 600

    autologin_user = _defaults_read("/Library/Preferences/com.apple.loginwindow", "autoLoginUser")

    if mode == "report":
        report_row(cat, "Require password after sleep/screensaver", "1",
                    _defaults_read("com.apple.screensaver", "askForPassword", current_host=True))
        report_row(cat, "Password delay (seconds)", "0",
                    _defaults_read("com.apple.screensaver", "askForPasswordDelay", current_host=True))
        report_row(cat, "Idle lock timeout (seconds)", str(idle_seconds),
                    _defaults_read("com.apple.screensaver", "idleTime", current_host=True))
        report_row(cat, "Automatic login user", "not set", autologin_user)
    elif mode == "restore":
        run(["defaults", "-currentHost", "delete", "com.apple.screensaver", "askForPassword"])
        run(["defaults", "-currentHost", "delete", "com.apple.screensaver", "askForPasswordDelay"])
        run(["defaults", "-currentHost", "delete", "com.apple.screensaver", "idleTime"])
        log(cat, "Password-on-wake / idle timeout", "Reverted to macOS defaults (unset)")
        log(cat, "Automatic login", "Left disabled - re-enabling passwordless login isn't offered")
    else:
        run(["defaults", "-currentHost", "write", "com.apple.screensaver", "askForPassword", "-int", "1"])
        run(["defaults", "-currentHost", "write", "com.apple.screensaver", "askForPasswordDelay", "-int", "0"])
        run(["defaults", "-currentHost", "write", "com.apple.screensaver", "idleTime", "-int", str(idle_seconds)])
        log(cat, "Require password immediately after sleep/screensaver, 10-minute idle lock", "Done")

        if autologin_user != "not set":
            run(["sudo", "defaults", "delete", "/Library/Preferences/com.apple.loginwindow", "autoLoginUser"])
            log(cat, "Automatic login", f"Disabled (was set for user: {autologin_user})")
        else:
            log(cat, "Automatic login", "Already disabled")


# ---------------------------------------------------------------------------
# Audit (report/verify only - see module docstring)
# ---------------------------------------------------------------------------

def category_audit(mode):
    cat = "Audit"
    _, listing, _ = sh(["launchctl", "list"])
    running = any(line.split()[-1] == "com.apple.auditd" for line in listing.splitlines() if line.strip())
    _, flags_line, _ = sh(["grep", "-E", "^flags:", "/etc/security/audit_control"])
    flags = flags_line.split(":", 1)[1].strip() if ":" in flags_line else "unknown"

    if mode == "report":
        report_row(cat, "auditd running", "running", "running" if running else "not running")
        report_row(cat, "audit_control flags", "present", flags)
    elif mode == "restore":
        log(cat, "Restore", "No-op - macOS ships auditd enabled with a reasonable flag set by "
                             "default; stopping the audit subsystem entirely isn't offered")
    else:
        if running:
            log(cat, "auditd", "Already running")
        else:
            run(["sudo", "launchctl", "kickstart", "-k", "system/com.apple.auditd"])
            log(cat, "auditd", "Started")
        log(cat, "audit_control flags", f"Left at macOS's shipped baseline ({flags}) - editing "
            "audit classes isn't offered by this script since a wrong edit can silently break "
            "the audit trail; review /etc/security/audit_control manually to add classes")


# ---------------------------------------------------------------------------
# Credential hardening
# ---------------------------------------------------------------------------

def _guest_enabled():
    _, out, _ = sh(["defaults", "read", "/Library/Preferences/com.apple.loginwindow", "GuestEnabled"])
    return out == "1"


PW_MIN_LENGTH = 14
PW_MAX_FAILED = 10
PW_LOCKOUT_SECONDS = 900

PW_RULE_LENGTH = "com.desktopconfigs.minLength"
PW_RULE_COMPLEXITY = "com.desktopconfigs.complexity"
PW_RULE_LOCKOUT = "com.desktopconfigs.lockout"

# 3 of 4 character types - the same rule as Windows' "meets complexity requirements"
# and Fedora's pwquality minclass=3. NSPredicate MATCHES anchors the whole string.
PW_COMPLEXITY_REGEX = (
    "(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9]).*"
    "|(?=.*[a-z])(?=.*[A-Z])(?=.*[^A-Za-z0-9]).*"
    "|(?=.*[a-z])(?=.*[0-9])(?=.*[^A-Za-z0-9]).*"
    "|(?=.*[A-Z])(?=.*[0-9])(?=.*[^A-Za-z0-9]).*"
)

PW_RULES = {
    "policyCategoryPasswordContent": [
        {
            "policyIdentifier": PW_RULE_LENGTH,
            "policyContent": f"policyAttributePassword matches '.{{{PW_MIN_LENGTH},}}+'",
            "policyParameters": {"minimumLength": PW_MIN_LENGTH},
            "policyContentDescription": {
                "en": f"Enter a password that is at least {PW_MIN_LENGTH} characters long."},
        },
        {
            "policyIdentifier": PW_RULE_COMPLEXITY,
            "policyContent": f"policyAttributePassword matches '{PW_COMPLEXITY_REGEX}'",
            "policyContentDescription": {
                "en": "Use at least three of: lowercase letters, uppercase letters, numbers, symbols."},
        },
    ],
    "policyCategoryAuthentication": [
        {
            "policyIdentifier": PW_RULE_LOCKOUT,
            "policyContent": (
                "(policyAttributeFailedAuthentications < policyAttributeMaximumFailedAuthentications) "
                "OR (policyAttributeCurrentTime > "
                "(policyAttributeLastFailedAuthenticationTime + autoEnableInSeconds))"
            ),
            "policyParameters": {
                "policyAttributeMaximumFailedAuthentications": PW_MAX_FAILED,
                "autoEnableInSeconds": PW_LOCKOUT_SECONDS,
            },
        },
    ],
}
PW_RULE_IDS = {rule["policyIdentifier"] for rules in PW_RULES.values() for rule in rules}


def _get_account_policies():
    """Current global pwpolicy as a dict ({} if none/unreadable)."""
    _, out, _ = sh(["pwpolicy", "-getaccountpolicies"])
    xml_start = out.find("<?xml")  # output is prefixed with a "Getting global..." line
    if xml_start < 0:
        return {}
    try:
        return plistlib.loads(out[xml_start:].encode())
    except plistlib.InvalidFileException:
        return {}


def _without_our_rules(policies):
    cleaned = {}
    for category, rules in policies.items():
        if not isinstance(rules, list):
            cleaned[category] = rules
            continue
        kept = [r for r in rules if r.get("policyIdentifier") not in PW_RULE_IDS]
        if kept:
            cleaned[category] = kept
    return cleaned


def _set_account_policies(policies):
    with tempfile.NamedTemporaryFile("wb", suffix=".plist", delete=False) as tmp:
        plistlib.dump(policies, tmp)
    try:
        run(["sudo", "pwpolicy", "-setaccountpolicies", tmp.name])
    finally:
        Path(tmp.name).unlink(missing_ok=True)


def _find_rule(policies, rule_id):
    for rules in policies.values():
        if isinstance(rules, list):
            for rule in rules:
                if rule.get("policyIdentifier") == rule_id:
                    return rule
    return None


def category_credential_hardening(mode):
    cat = "CredentialHardening"

    if mode == "report":
        report_row(cat, "Guest account enabled", "0", "1" if _guest_enabled() else "0")
        policies = _get_account_policies()
        length = _find_rule(policies, PW_RULE_LENGTH)
        report_row(cat, "Password minimum length", str(PW_MIN_LENGTH),
                    str(length["policyParameters"]["minimumLength"]) if length else "not set")
        report_row(cat, "Password complexity (3 of 4 character types)", "required",
                    "required" if _find_rule(policies, PW_RULE_COMPLEXITY) else "not set")
        lockout = _find_rule(policies, PW_RULE_LOCKOUT)
        params = lockout["policyParameters"] if lockout else {}
        report_row(cat, "Lockout threshold (bad attempts)", str(PW_MAX_FAILED),
                    str(params.get("policyAttributeMaximumFailedAuthentications", "not set")))
        report_row(cat, "Lockout duration (seconds)", str(PW_LOCKOUT_SECONDS),
                    str(params.get("autoEnableInSeconds", "not set")))
    elif mode == "restore":
        log(cat, "Guest account", "Left disabled - already macOS's stock default")
        policies = _get_account_policies()
        if any(_find_rule(policies, rule_id) for rule_id in PW_RULE_IDS):
            _set_account_policies(_without_our_rules(policies))
            log(cat, "Password/lockout policy", "This script's rules removed - macOS's stock policy applies")
        else:
            log(cat, "Password/lockout policy", "No rules from this script present - nothing to revert")
    else:
        if _guest_enabled():
            run(["sudo", "sysadminctl", "-guestAccount", "off"])
            log(cat, "Guest account", "Disabled")
        else:
            log(cat, "Guest account", "Already disabled")

        policies = _without_our_rules(_get_account_policies())
        for category, rules in PW_RULES.items():
            policies.setdefault(category, []).extend(rules)
        _set_account_policies(policies)
        log(cat, "Password/lockout policy",
            f"Minimum length {PW_MIN_LENGTH}, 3 of 4 character types, "
            f"{PW_LOCKOUT_SECONDS // 60}-minute lockout after {PW_MAX_FAILED} bad attempts "
            "(checked at next password change)")


# ---------------------------------------------------------------------------
# Privacy
# ---------------------------------------------------------------------------

DIAG_PLIST = "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory"
DIAG_KEYS = [
    ("AutoSubmit", "Share Mac Analytics with Apple"),
    ("ThirdPartyDataSubmit", "Share crash data with app developers"),
]


def category_privacy(mode):
    cat = "Privacy"

    if mode == "report":
        for key, label in DIAG_KEYS:
            rc, out, _ = sh(["sudo", "defaults", "read", DIAG_PLIST, key])
            report_row(cat, label, "0", out if rc == 0 else "not set")
        report_row(cat, "Crash reporter dialog", "none",
                    _defaults_read("com.apple.CrashReporter", "DialogType"))
        report_row(cat, "Personalized Apple Advertising", "0",
                    _defaults_read("com.apple.AdLookup", "allowApplePersonalizedAdvertising", current_host=True))
    elif mode == "restore":
        for key, _ in DIAG_KEYS:
            sh(["sudo", "defaults", "delete", DIAG_PLIST, key])
        run(["defaults", "delete", "com.apple.CrashReporter", "DialogType"])
        run(["defaults", "-currentHost", "delete", "com.apple.AdLookup", "allowApplePersonalizedAdvertising"])
        log(cat, "Analytics sharing / crash dialog / personalized advertising",
            "Reverted to macOS defaults (unset)")
    else:
        for key, _ in DIAG_KEYS:
            run(["sudo", "defaults", "write", DIAG_PLIST, key, "-bool", "false"])
        log(cat, "Mac Analytics sharing (Apple + app developers)", "Disabled")
        run(["defaults", "write", "com.apple.CrashReporter", "DialogType", "-string", "none"])
        log(cat, "Crash reporter dialog", "Silenced")
        run(["defaults", "-currentHost", "write", "com.apple.AdLookup",
             "allowApplePersonalizedAdvertising", "-bool", "false"])
        log(cat, "Personalized Apple Advertising", "Disabled")


# ---------------------------------------------------------------------------
# Software Update policy
# ---------------------------------------------------------------------------

def category_software_update(mode):
    cat = "SoftwareUpdate"
    plist = "/Library/Preferences/com.apple.SoftwareUpdate.plist"
    keys = [
        "AutomaticallyInstallMacOSUpdates",
        "AutomaticCheckEnabled",
        "AutomaticDownload",
        "CriticalUpdateInstall",
        "ConfigDataInstall",
    ]

    if mode == "report":
        for key in keys:
            report_row(cat, key, "1", _defaults_read(plist, key))
    elif mode == "restore":
        for key in keys:
            run(["sudo", "defaults", "delete", plist, key])
        log(cat, "Auto-update policy", "Reverted to macOS defaults (unset)")
    else:
        for key in keys:
            run(["sudo", "defaults", "write", plist, key, "-bool", "true"])
        log(cat, "Auto-update policy (check/download/install security & OS updates)", "Enabled")
        log(cat, "Note", "This only sets policy - to install what's already pending, run 04.Update-Mac.py")


# ---------------------------------------------------------------------------
# Microsoft Edge (Chromium managed policy via a manually-placed plist -
# see the --edge docstring entry for the caveat)
# ---------------------------------------------------------------------------

EDGE_APP_PATH = Path("/Applications/Microsoft Edge.app")

# Same policy set as 05.Secure-Windows.ps1's -Edge / -EdgeStrict - keep them in sync.
EDGE_BASELINE_POLICIES = [
    ("SmartScreenEnabled", "bool", "true"),
    ("SmartScreenPuaEnabled", "bool", "true"),
    ("SmartScreenForTrustedDownloadsEnabled", "bool", "true"),
    ("BlockThirdPartyCookies", "bool", "true"),
    ("TrackingPrevention", "int", "2"),
    ("PasswordLeakDetectionEnabled", "bool", "true"),
    ("AutofillCreditCardEnabled", "bool", "false"),
    ("NetworkPredictionOptions", "int", "2"),
    ("AlternateErrorPagesEnabled", "bool", "false"),
    ("EdgeShoppingAssistantEnabled", "bool", "false"),
    ("PersonalizationReportingEnabled", "bool", "false"),
    ("UserFeedbackAllowed", "bool", "false"),
    ("ConfigureDoNotTrack", "bool", "true"),
    ("MetricsReportingEnabled", "bool", "false"),
    ("EnhanceSecurityMode", "int", "1"),
    ("StartupBoostEnabled", "bool", "false"),
]

EDGE_STRICT_POLICIES = [
    ("TrackingPrevention", "int", "3"),
    ("EnhanceSecurityMode", "int", "2"),
    ("BrowserSignin", "int", "0"),
    ("SyncDisabled", "bool", "true"),
    ("PasswordManagerEnabled", "bool", "false"),
    ("SearchSuggestEnabled", "bool", "false"),
    ("SSLErrorOverrideAllowed", "bool", "false"),
    ("HttpsOnlyMode", "string", "force_enabled"),
]


def _edge_installed():
    return EDGE_APP_PATH.exists()


def _edge_plist_domain():
    return f"/Library/Managed Preferences/{Path.home().name}/com.microsoft.Edge"


def _edge_read(key):
    rc, out, _ = sh(["defaults", "read", _edge_plist_domain(), key])
    return out if rc == 0 else "not set"


def _edge_expected(kind, value):
    # 'defaults read' prints booleans as 1/0, so compare against that form.
    if kind == "bool":
        return "1" if value == "true" else "0"
    return value


def _edge_write(policies):
    domain = _edge_plist_domain()
    run(["sudo", "mkdir", "-p", str(Path(domain).parent)])
    for key, kind, value in policies:
        run(["sudo", "defaults", "write", domain, key, f"-{kind}", value])


def _edge_remove(policies):
    domain = _edge_plist_domain()
    for key, _, _ in policies:
        sh(["sudo", "defaults", "delete", domain, key])


def _edge_skip(cat, mode):
    if mode == "report":
        report_row(cat, "Microsoft Edge installed", "yes", "no - category skipped")
    else:
        log(cat, "Skipped", "Microsoft Edge is not installed "
                             "(/Applications/Microsoft Edge.app not found)")


def category_edge(mode):
    cat = "Edge"
    if not _edge_installed():
        _edge_skip(cat, mode)
        return

    if mode == "report":
        for key, kind, value in EDGE_BASELINE_POLICIES:
            report_row(cat, key, _edge_expected(kind, value), _edge_read(key))
    elif mode == "restore":
        _edge_remove(EDGE_BASELINE_POLICIES)
        log(cat, "Baseline policies removed", "Reverted to Edge defaults (unmanaged) - "
                                               "fully quit and relaunch Edge to pick this up")
    else:
        _edge_write(EDGE_BASELINE_POLICIES)
        log(cat, f"{len(EDGE_BASELINE_POLICIES)} browser privacy/security policies (SmartScreen, "
                  "tracking prevention, cookie blocking, telemetry off, etc.)",
            "Applied - fully quit and relaunch Edge, then check edge://policy to confirm")


def category_edge_strict(mode):
    cat = "EdgeStrict"
    if not _edge_installed():
        _edge_skip(cat, mode)
        return

    if mode == "report":
        for key, kind, value in EDGE_STRICT_POLICIES:
            report_row(cat, key, _edge_expected(kind, value), _edge_read(key))
    elif mode == "restore":
        _edge_remove(EDGE_STRICT_POLICIES)
        log(cat, "Strict policies removed", "Reverted (unmanaged), including HTTPS-Only mode - "
                                             "fully quit and relaunch Edge to pick this up")
    else:
        _edge_write(EDGE_STRICT_POLICIES)
        log(cat, "Strict tracking prevention + security mode, sign-in/sync disabled, password manager off, "
                  "search-suggest off, cert-bypass blocked, HTTPS-Only forced",
            "Applied - NOTE: HTTPS-Only mode WILL break any plain-HTTP intranet page you browse "
            "to. Fully quit and relaunch Edge, then check edge://policy to confirm")


# ---------------------------------------------------------------------------
# Separate admin account (opt-in, always runs last - see the --separate-admin
# docstring entry for the safety checks and their order)
# ---------------------------------------------------------------------------

ADMIN_GROUP_SYSTEM_MEMBERS = {"root", "_mbsetupuser"}
SHORT_NAME_PATTERN = re.compile(r"^[a-z_][a-z0-9_-]{0,31}$")


def _current_user():
    return os.environ.get("SUDO_USER") or getpass.getuser()


def _user_exists(user):
    return sh(["dscl", ".", "-read", f"/Users/{user}", "UniqueID"])[0] == 0


def _is_admin(user):
    rc, out, _ = sh(["dseditgroup", "-o", "checkmember", "-m", user, "admin"])
    return rc == 0 and out.startswith("yes")


def _admin_members():
    _, out, _ = sh(["dscl", ".", "-read", "/Groups/admin", "GroupMembership"])
    members = out.split(":", 1)[1].split() if ":" in out else []
    return [m for m in members if m not in ADMIN_GROUP_SYSTEM_MEMBERS]


def _has_secure_token(user):
    _, out, err = sh(["sysadminctl", "-secureTokenStatus", user])
    return "ENABLED" in out + err  # sysadminctl reports this on stderr


def category_separate_admin(mode, new_admin, demote_user):
    cat = "SeparateAdmin"
    demote_user = demote_user or _current_user()

    if mode == "report":
        report_row(cat, f"'{demote_user}' is an administrator", "no", "yes" if _is_admin(demote_user) else "no")
        if new_admin:
            ok = _user_exists(new_admin) and _is_admin(new_admin)
            report_row(cat, f"Separate admin account '{new_admin}'", "yes", "yes" if ok else "no")
        else:
            others = [m for m in _admin_members() if m != demote_user]
            report_row(cat, f"Separate admin account exists ({', '.join(others) or 'none'})",
                       "yes", "yes" if others else "no")
        return

    if mode == "restore":
        if _is_admin(demote_user):
            log(cat, f"'{demote_user}' admin rights", "Already an administrator - nothing to do")
        else:
            run(["sudo", "dseditgroup", "-o", "edit", "-a", demote_user, "-t", "user", "admin"])
            log(cat, f"'{demote_user}' admin rights",
                "Restored" if _is_admin(demote_user) else "FAILED - check 'dseditgroup -o checkmember'")
        log(cat, "Admin account", "Left in place - deleting accounts isn't offered; remove it in "
                                  "System Settings > Users & Groups if you no longer need it")
        return

    if not new_admin:
        new_admin = input("Short name for the new admin account (e.g. localadmin): ").strip()
    if not SHORT_NAME_PATTERN.match(new_admin or ""):
        log(cat, "Harden", f"Skipped - '{new_admin}' isn't a valid short name (lowercase letters, "
                           "digits, _ or -, starting with a letter)")
        return
    if new_admin == demote_user:
        log(cat, "Harden", "Skipped - the new admin account can't be the account being demoted")
        return

    need_token = _has_secure_token(demote_user)
    exists = _user_exists(new_admin)
    print(f"\nThis will {'reuse' if exists else 'create'} the admin account '{new_admin}', then remove "
          f"'{demote_user}' from the admin group.")
    print(f"Afterwards '{demote_user}' can't use sudo or approve admin prompts - you'll enter "
          f"'{new_admin}' and its password instead.")
    if input("Type YES to continue: ").strip() != "YES":
        log(cat, "Harden", "Cancelled - nothing changed")
        return

    if exists:
        if not _is_admin(new_admin):
            log(cat, "Harden", f"Stopped - '{new_admin}' already exists but isn't an admin; pick another name")
            return
        log(cat, f"Admin account '{new_admin}'", "Already exists - reusing it")
    else:
        cmd = ["sudo", "sysadminctl", "-addUser", new_admin, "-fullName", "Administrator",
               "-password", "-", "-admin"]
        if need_token:
            # Granting a Secure Token needs an existing token holder's credentials.
            cmd += ["-adminUser", demote_user, "-adminPassword", "-"]
            print(f"sysadminctl will ask for the NEW account's password, and for the password of "
                  f"'{demote_user}' (to give the new account a Secure Token). Read each prompt carefully.")
        else:
            print("sysadminctl will ask for the NEW account's password.")
        run(cmd)
        if not (_user_exists(new_admin) and _is_admin(new_admin)):
            log(cat, "Harden", f"Stopped - '{new_admin}' wasn't created as an admin; '{demote_user}' "
                               "left unchanged")
            return
        log(cat, f"Admin account '{new_admin}'", "Created")

    print(f"Confirm the password for '{new_admin}' - type it again:")
    if subprocess.run(["dscl", ".", "-authonly", new_admin]).returncode != 0:
        log(cat, "Harden", f"Stopped - the password for '{new_admin}' didn't authenticate; '{demote_user}' left "
                           f"unchanged. Reset it with: sudo sysadminctl -resetPasswordFor {new_admin} "
                           "-newPassword -")
        return

    if need_token and not _has_secure_token(new_admin):
        log(cat, "Harden", f"Stopped - '{new_admin}' has no Secure Token, so it couldn't install macOS "
                           f"updates or unlock FileVault; '{demote_user}' left unchanged. Grant one with: "
                           f"sudo sysadminctl -secureTokenOn {new_admin} -password - "
                           f"-adminUser {demote_user} -adminPassword -")
        return

    if not _is_admin(demote_user):
        log(cat, f"'{demote_user}' admin rights", "Already a standard user")
        return
    run(["sudo", "dseditgroup", "-o", "edit", "-d", demote_user, "-t", "user", "admin"])
    if _is_admin(demote_user):
        log(cat, f"'{demote_user}' admin rights", "FAILED - still an administrator")
    else:
        log(cat, f"'{demote_user}' admin rights",
            f"Removed - now a standard user; use '{new_admin}' when macOS asks for an administrator")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--all", action="store_true", help="Run every category.")
    parser.add_argument("--firewall", action="store_true")
    parser.add_argument("--filevault", action="store_true")
    parser.add_argument("--gatekeeper", action="store_true")
    parser.add_argument("--sip", action="store_true")
    parser.add_argument("--ssh", action="store_true")
    parser.add_argument("--keep-ssh", action="store_true", dest="keep_ssh",
                         help="Modifier for --ssh: keep Remote Login enabled but hardened.")
    parser.add_argument("--keep-password-auth", action="store_true", dest="keep_password_auth",
                         help="Modifier for --ssh --keep-ssh: keep SSH password authentication enabled.")
    parser.add_argument("--sharing", action="store_true")
    parser.add_argument("--sudo", action="store_true")
    parser.add_argument("--lockscreen", action="store_true")
    parser.add_argument("--audit", action="store_true")
    parser.add_argument("--credential-hardening", action="store_true", dest="credential_hardening")
    parser.add_argument("--privacy", action="store_true")
    parser.add_argument("--software-update", action="store_true", dest="software_update")
    parser.add_argument("--edge", action="store_true")
    parser.add_argument("--edge-strict", action="store_true", dest="edge_strict",
                         help="NOT included in --all - opt in explicitly. Escalates tracking "
                              "prevention to Strict, disables sign-in/sync and the password "
                              "manager, blocks cert-warning bypass, and forces HTTPS-Only mode.")
    parser.add_argument("--separate-admin", action="store_true", dest="separate_admin",
                         help="NOT included in --all - opt in explicitly. Creates a separate admin "
                              "account and removes the current user from the admin group.")
    parser.add_argument("--new-admin", metavar="NAME", dest="new_admin",
                         help="Modifier for --separate-admin: short name of the admin account.")
    parser.add_argument("--demote-user", metavar="NAME", dest="demote_user",
                         help="Modifier for --separate-admin: account to demote (default: current user).")
    parser.add_argument("--restore-defaults", action="store_true", dest="restore_defaults")
    parser.add_argument("--report", action="store_true")
    return parser


def main():
    parser = build_parser()
    if len(sys.argv) == 1:
        parser.print_help()
        return
    args = parser.parse_args()

    if args.report and args.restore_defaults:
        print("--report and --restore-defaults cannot be combined - pick one.", file=sys.stderr)
        sys.exit(1)

    selected = {
        "firewall": args.firewall,
        "filevault": args.filevault,
        "gatekeeper": args.gatekeeper,
        "sip": args.sip,
        "ssh": args.ssh,
        "sharing": args.sharing,
        "sudo": args.sudo,
        "lockscreen": args.lockscreen,
        "audit": args.audit,
        "credential_hardening": args.credential_hardening,
        "privacy": args.privacy,
        "software_update": args.software_update,
        "edge": args.edge,
    }
    if args.all:
        selected = {k: True for k in selected}
    # edge_strict and separate_admin are opt-in only, not part of --all
    edge_strict = args.edge_strict
    separate_admin = args.separate_admin

    if not any(selected.values()) and not edge_strict and not separate_admin:
        print("No categories selected. Use --all or specific flags. Run with --help for details.")
        return

    mode = "report" if args.report else "restore" if args.restore_defaults else "harden"
    start_sudo_keepalive()

    if selected["firewall"]:
        category_firewall(mode)
    if selected["filevault"]:
        category_filevault(mode)
    if selected["gatekeeper"]:
        category_gatekeeper(mode)
    if selected["sip"]:
        category_sip(mode)
    if selected["ssh"]:
        category_ssh(mode, args.keep_ssh, args.keep_password_auth)
    if selected["sharing"]:
        category_sharing(mode)
    if selected["sudo"]:
        category_sudo(mode)
    if selected["lockscreen"]:
        category_lockscreen(mode)
    if selected["audit"]:
        category_audit(mode)
    if selected["credential_hardening"]:
        category_credential_hardening(mode)
    if selected["privacy"]:
        category_privacy(mode)
    if selected["software_update"]:
        category_software_update(mode)
    if selected["edge"]:
        category_edge(mode)
    if edge_strict:
        category_edge_strict(mode)
    # Last on purpose: once the current user is demoted, sudo stops working for it.
    if separate_admin:
        category_separate_admin(mode, args.new_admin, args.demote_user)

    print()
    if mode == "report":
        if REPORT:
            print_table(
                [[r.category, r.setting, r.expected, r.found, r.status] for r in REPORT],
                ["Category", "Setting", "Expected", "Found", "Status"],
            )
            mismatches = [r for r in REPORT if r.status == "MISMATCH"]
            print()
            if mismatches:
                for r in mismatches:
                    print(f" - [{r.category}] {r.setting}: expected '{r.expected}', found '{r.found}'")
                print(f"\n{len(mismatches)} setting(s) do not match the hardened baseline.")
            else:
                print("All checked settings match the hardened baseline.")
    elif RESULTS:
        print_table([[r.category, r.action, r.status] for r in RESULTS], ["Category", "Action", "Status"])


if __name__ == "__main__":
    main()
