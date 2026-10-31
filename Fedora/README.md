# Fedora

Scripts for setting up, configuring, updating and hardening **Fedora Workstation (GNOME)**. They're numbered in the order you'd run them on a new machine:

| Step | Script | When to run it |
|---|---|---|
| 1 | [01.Setup-Fedora.sh](01.Setup-Fedora.sh) | Once, right after a fresh Fedora install |
| 2 | [02.Configure-Fedora.sh](02.Configure-Fedora.sh) | Once, after setup |
| 4 | [04.Update-Fedora.sh](04.Update-Fedora.sh) | Any time, for recurring updates |
| 5 | [05.Secure-Fedora.sh](05.Secure-Fedora.sh) | Any time after setup (optional) |

## Requirements

- Fedora Workstation with GNOME and `dnf`.
- Run scripts 01, 02 and 04 as your **normal user** (they use `sudo` themselves where needed). Run 05 with `sudo`.
- Run 01 and 02 from a terminal **inside your GNOME session** — GNOME settings and extensions need it.
- All scripts are safe to re-run: steps that are already done are skipped or re-applied with the same result.

If a script won't run, make it executable first: `chmod +x *.sh`.

Running any script with no options just shows its help — nothing changes until you pass `--run` (or the script's own options).

---

## 01.Setup-Fedora.sh — first-run setup

Gets a freshly installed Fedora system ready:

1. Sets the hostname (see `--machine-name` below).
2. Adds the RPM Fusion repositories (for codecs and drivers Fedora doesn't ship) and upgrades the whole system.
3. **Reboots if the upgrade needs it**, after a 10-second countdown (Ctrl+C cancels). Just run the script again afterwards — it picks up where it left off.
4. Asks which apps you want from a menu per category: Comms, Media, Office Apps, Utilities, Dev, Creative, Others and AI. This comes *after* the reboot check, so you only answer once. Everything after this runs unattended.
5. Switches Flatpak to Flathub and installs your picks (Flathub or `dnf`). VS Code comes from Microsoft's own repository; picking Wireshark also adds you to the `wireshark` group so you can capture packets.
6. Always installs: git and archive tools (7-Zip, unrar), Microsoft core fonts, AppImage support, AMD graphics drivers with hardware video acceleration, full multimedia codecs, GNOME Tweaks and a set of GNOME extensions (Dash to Panel, Blur my Shell, Just Perfection, Bluetooth Battery Meter, Background Logo).

```bash
./01.Setup-Fedora.sh --run                              # asks for everything
./01.Setup-Fedora.sh --install-all                      # no app menus - install every app
./01.Setup-Fedora.sh --machine-name dev-laptop --install-all   # no prompts except sudo's password
```

| Option | What it does |
|---|---|
| `--run` | Runs setup, asking for anything not given on the command line. Not needed when `--machine-name` or `--install-all` is given. |
| `--machine-name NAME` | Hostname to set. Without it you're asked every run — passing it saves answering again after the mid-setup reboot. The "pretty" name is used as typed; the system hostname gets a cleaned-up version (`Tim's Laptop` → `tims-laptop`). |
| `--install-all` | Skips the app menus and installs every app in every category. |

**Menu keys:** `A` = all apps in the category, `S` or Enter = skip it, `Q` = quit, or numbers such as `1,3`.

**About the AI menu:** Claude and ChatGPT have no official Linux desktop apps, so choosing them adds an app-grid icon that opens claude.ai / chatgpt.com in your browser. Claude Code is installed properly, with Anthropic's official installer.

> The Adobe Acrobat Reader Flatpak wraps Adobe's Linux app, which hasn't been updated since 2013. GNOME's built-in document viewer is a maintained alternative.

When it finishes, run `02.Configure-Fedora.sh --run`, then log out and back in so extensions and group changes take effect.

---

## 02.Configure-Fedora.sh — preference settings

Applies preferences for your account:

- Minimize/maximize buttons on windows.
- 24-hour clock in the top bar and in file-picker dialogs.
- 90% opacity for the default Ptyxis terminal profile.
- Stops GNOME Software starting in the background at every login (updates are handled by `04.Update-Fedora.sh`).
- **AirPlay speaker discovery**, so AirPlay speakers on your network appear in Sound settings. This is permanent (it survives reboots). On Fedora 43 and later it uses Fedora's `pipewire-config-raop` package; on older releases it writes the same setting to `~/.config/pipewire/`. The audio services restart once, so sound drops for about a second.

```bash
./02.Configure-Fedora.sh --run
```

No other options. It refuses to run as root or outside a desktop session, with an explanation.

---

## 04.Update-Fedora.sh — recurring updates

Updates everything in one go:

1. System packages (`dnf update`).
2. Flatpak apps.
3. Device firmware (`fwupdmgr`) — this step may ask you to confirm.
4. Cleans the package cache and removes packages nothing needs any more.

```bash
./04.Update-Fedora.sh --run
```

> **Reboots immediately, without a countdown,** if the updates need it — save your work first.

---

## 05.Secure-Fedora.sh — security hardening (optional)

Applies reversible security settings in independent categories. Must be run with `sudo`. Each category has three modes:

- **Harden** (default): applies the settings.
- **`--report`**: changes nothing; prints a table of each setting's expected and actual value, with mismatches listed at the end.
- **`--restore-defaults`**: puts the selected categories back to Fedora's out-of-box settings.

```bash
sudo ./05.Secure-Fedora.sh --all --report     # see what would change - start here
sudo ./05.Secure-Fedora.sh --all              # apply every standard category
sudo ./05.Secure-Fedora.sh --firewall --ssh --sudo --selinux
sudo ./05.Secure-Fedora.sh --ssh --sudo --restore-defaults
sudo ./05.Secure-Fedora.sh --help             # full reference
```

| Category | What hardening does |
|---|---|
| `--firewall` | firewalld on, dropped packets logged. Warns if the default zone is "trusted". |
| `--selinux` | SELinux set to Enforcing. |
| `--luks` | Reports whether the disk is encrypted. It can't be turned on after install — reinstall with "Encrypt my data" ticked. |
| `--ssh` | Turns the SSH server off. With `--keep-ssh`, keeps it on but hardened: no root login, key-only sign-in if keys are set up (add `--keep-password-auth` to keep passwords). |
| `--network-discovery` | Turns off Avahi/mDNS and LLMNR network discovery. |
| `--sudo` | sudo always asks for your password and logs every command to `/var/log/sudo.log`. |
| `--services` | Disables rarely needed network services (rpcbind, NFS server, telnet, Samba, GNOME Remote Desktop). |
| `--lockscreen` | 10-minute idle lock, no automounting of USB drives (locked so users can't change them), automatic login off. |
| `--audit` | Installs and enables `auditd`, with rules watching account files, sudo configuration, logins and privileged commands. |
| `--credential-hardening` | Passwords must be 14+ characters with 3 of 4 character types; 15-minute lockout after 10 wrong attempts. |
| `--attack-surface-extras` | Kernel and network hardening settings, core dumps off, rare filesystems blocked, Ctrl+Alt+Del reboot disabled. |
| `--privacy` | Turns off automatic crash reporting, network connectivity checks and recent-files tracking. |
| `--auto-update` | Installs security updates automatically every day (never reboots by itself). |
| `--firefox` | Firefox privacy policies: telemetry off, third-party cookies blocked, DNS-over-HTTPS on. DNS-over-HTTPS can break internal/home lab host names. |
| `--sysmon` | Installs Microsoft's Sysmon for Linux with a standard baseline configuration (downloads from Microsoft/GitHub). |
| `--dnf-update` / `--flatpak-update` | Installs pending updates. `--report` shows how many are pending. |

**Opt-in categories** — not included in `--all`; you must name them:

| Category | What it does |
|---|---|
| `--privacy-strict` | Turns off location services and blocks the webcam — **breaks Zoom, Teams and other video apps** until restored. |
| `--firefox-strict` | Stricter Firefox policies, including HTTPS-only mode, which **breaks plain-HTTP sites**. |
| `--separate-admin` | Creates a separate admin account and removes admin rights from your everyday account. See below. |

### `--separate-admin`

Moves you to a standard (non-admin) everyday account, with a separate account for admin tasks:

```bash
sudo ./05.Secure-Fedora.sh --separate-admin --new-admin localadmin
```

1. Shows the plan and asks you to type `YES`.
2. Creates the admin account in the `wheel` group (or reuses it). You set its password with `passwd`, typed twice; if that fails, the half-created account is removed again.
3. Checks the account has a password and that sudo really gives it full rights.
4. Only then removes your account from `wheel`. Any failed check stops before this point, leaving your account unchanged.

Log out and back in afterwards — terminals already open keep sudo until you do. Options: `--new-admin NAME` (otherwise you're asked), `--demote-user NAME` (default: the user who ran sudo). To undo, run as the admin account: `sudo ./05.Secure-Fedora.sh --separate-admin --demote-user YOURNAME --restore-defaults`. The admin account is never deleted automatically.
