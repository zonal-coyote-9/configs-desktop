# Mac

Scripts for setting up, configuring, updating and hardening a Mac. They're numbered in the order you'd run them on a new machine:

| Step | Script | When to run it |
|---|---|---|
| 1 | [01.Setup-Mac.py](01.Setup-Mac.py) | Once, right after a fresh macOS install |
| 2 | [02.Configure-Mac.py](02.Configure-Mac.py) | Once, after setup |
| 4 | [04.Update-Mac.py](04.Update-Mac.py) | Any time, for recurring updates |
| 5 | [05.Secure-Mac.py](05.Secure-Mac.py) | Any time after setup (optional) |
| – | [MacSystemInfo.py](MacSystemInfo.py) | Any time, to see hardware/software details |

## Requirements

- Python 3, which macOS provides once the Xcode Command Line Tools are installed (`01.Setup-Mac.py` installs them).
- Run each script from Terminal as your **normal user**, not with `sudo`. Scripts that need administrator rights ask for your password **once** at the start, then run unattended.
- Every script is self-contained, so any one can be copied and run on its own.
- All scripts are safe to re-run: steps that are already done are skipped or re-applied with the same result.

Run a script with `./01.Setup-Mac.py` (they're executable) or `python3 01.Setup-Mac.py`. Running a script with no options shows its help — nothing changes until you pass `--run` (or the script's own options).

---

## 01.Setup-Mac.py — first-run setup

Gets a freshly installed Mac ready:

1. Sets the computer name (see `--machine-name` below).
2. Asks which apps you want from a menu per category: Comms, Media, Office Apps, Utilities, Dev, Creative, Others, AI, and a Mac-only **CLI Tools** menu (modern replacements like `eza` and `bat` used by the shell aliases). All menus are answered up front, so the long installs run unattended.
3. Installs the Xcode Command Line Tools (a system dialog appears; click through it).
4. Installs Homebrew and adds it to your shell's `PATH`.
5. Installs the apps you picked with Homebrew, or the Mac App Store for App Store apps. `mas` (the App Store command-line tool) is installed automatically if you picked any App Store apps. Any failures are listed at the end.

```bash
./01.Setup-Mac.py --run                                      # asks for everything
./01.Setup-Mac.py --install-all                              # no app menus - install every app
./01.Setup-Mac.py --machine-name "Tim's MacBook Pro" --install-all   # no prompts except your password
```

| Option | What it does |
|---|---|
| `--run` | Runs setup, asking for anything not given on the command line. Not needed when `--machine-name` or `--install-all` is given. |
| `--machine-name NAME` | Sets the computer name, even if the Mac was renamed before. Without it, you're only asked while the Mac still has its factory name (e.g. "Tim's MacBook Pro"). The friendly name is used as typed; the network host name gets a cleaned-up version (`tims-macbook-pro`). |
| `--install-all` | Skips the app menus and installs every app in every category. |

**Menu keys:** `A` = all apps in the category, `S` or Enter = skip it, `Q` = quit without installing anything, or numbers such as `1,3`.

> Cricut Design Space isn't available through Homebrew — install it from cricut.com/setup.

---

## 02.Configure-Mac.py — preference settings

Applies a set of macOS preferences, then restarts the affected apps (Finder, Dock, etc.) so they take effect:

- **Dock:** 48px icons, no recent apps, running-app indicators.
- **Finder:** status and path bars, all file extensions shown, list view everywhere, folders sorted first, search the current folder, no warnings when changing extensions or emptying the Trash, no `.DS_Store` files on network/USB drives. It also **resets saved per-folder view settings** (deletes `.DS_Store` files under your home folder, except on the Desktop) so list view applies everywhere.
- **Look and feel:** less-rounded window corners, traditional sidebar, menu bar clock with date, system-wide 24-hour time.
- **Apps:** TextEdit opens plain-text documents; Mail and Music tweaks; Photos doesn't open when a device is plugged in; save dialogs and print panels open expanded; new documents save to disk instead of iCloud.
- **Input:** tap to click, bottom-right-corner right-click, full keyboard access.
- **System:** startup chime muted, Application Firewall and stealth mode on, automatic software updates on, a login-window message, and system info shown when you click the login-window clock.
- **Terminal:** installs the files from [Terminal/](Terminal/) (see below) and the "PowerShell" Terminal profile.
- **Folder redirection (optional):** moves Desktop, Documents and Downloads into a cloud storage folder and leaves shortcuts behind, so they sync.

```bash
./02.Configure-Mac.py --run                        # asks whether to redirect folders (Enter = no)
./02.Configure-Mac.py --cloudstorage 'OneDrive'    # redirect into OneDrive without asking
./02.Configure-Mac.py --cloudstorage None          # skip redirection without asking
```

| Option | What it does |
|---|---|
| `--run` | Applies the settings, asking about folder redirection. Not needed when `--cloudstorage` is given. |
| `--cloudstorage NAME` | `'OneDrive'`, `'Proton Drive'`, `'iCloud Drive'`, or `'None'`. Case and spacing don't matter (`onedrive`, `icloud` work). Also accepted as `--cloud-storage`. |

**About folder redirection:**
- The provider's app must already be installed, signed in and synced. If its folder isn't found, redirection is skipped with a message rather than moving files into a folder that doesn't sync.
- Downloads goes inside Documents in the cloud (OneDrive doesn't sync a top-level Downloads folder).
- A file that already exists in the cloud folder is never overwritten. If anything can't be moved, that folder is left where it is with those files still inside.

> **Heads-up:**
> - This **replaces** your `~/.zshrc` and PowerShell profile with the repo's versions — copy anything you want to keep first.
> - The TextEdit settings need your terminal app to have **Full Disk Access** (System Settings › Privacy & Security). The script tells you if they couldn't be applied.

---

## 04.Update-Mac.py — recurring updates

Updates everything in one go:

1. Homebrew: `brew update`, upgrades all formulae and casks, cleans up old versions, and runs `brew doctor`.
2. Mac App Store apps (if `mas` is installed).
3. macOS itself with `softwareupdate --all --install`.

```bash
./04.Update-Mac.py --run
```

> **The Mac restarts automatically** if a macOS update needs it — save your work first.

---

## 05.Secure-Mac.py — security hardening (optional)

Applies reversible security settings in independent categories. Each category has three modes:

- **Harden** (default): applies the settings.
- **`--report`**: changes nothing; prints a table of each setting's expected and actual value, with mismatches listed at the end.
- **`--restore-defaults`**: puts the selected categories back to macOS's out-of-box settings.

```bash
./05.Secure-Mac.py --all --report        # see what would change - start here
./05.Secure-Mac.py --all                 # apply every standard category
./05.Secure-Mac.py --firewall --filevault --gatekeeper
./05.Secure-Mac.py --ssh --lockscreen --restore-defaults
```

| Category | What hardening does |
|---|---|
| `--firewall` | Application Firewall, stealth mode and blocked-connection logging on. |
| `--filevault` | Turns on disk encryption. **Save the recovery key it prints.** Restore decrypts the disk (slow; warns first). |
| `--gatekeeper` | Makes sure Gatekeeper and download quarantine (the "downloaded from the internet" check) are on. |
| `--sip` | Reports whether System Integrity Protection is on. It can only be changed from Recovery Mode, so this never changes it. |
| `--ssh` | Turns Remote Login (SSH) off. With `--keep-ssh`, keeps it on but hardened: no root login, key-only sign-in if you have keys set up (add `--keep-password-auth` to keep passwords). |
| `--sharing` | Turns off File Sharing, Screen Sharing and Remote Apple Events. |
| `--sudo` | Per-terminal sudo sessions, and every sudo command logged to `/var/log/sudo.log`. |
| `--lockscreen` | Password required immediately after sleep or screen saver, 10-minute idle lock, automatic login off. |
| `--audit` | Checks the built-in audit system is running (report only; doesn't edit its settings). |
| `--credential-hardening` | Guest account off; passwords must be 14+ characters with 3 of 4 character types; 15-minute lockout after 10 wrong attempts. Existing passwords keep working until next changed. |
| `--privacy` | Stops sharing Mac Analytics with Apple and app developers, silences the crash dialog, turns off personalized ads. |
| `--software-update` | Turns on automatic checking, downloading and installing of updates (doesn't install anything now — use `04.Update-Mac.py`). |
| `--edge` | Microsoft Edge security/privacy policies (skipped if Edge isn't installed). Fully quit and reopen Edge, then check `edge://policy`. |

**Opt-in categories** — not included in `--all`; you must name them:

| Category | What it does |
|---|---|
| `--edge-strict` | Stricter Edge policies, including HTTPS-only mode, which **breaks plain-HTTP sites** (e.g. home lab pages). |
| `--separate-admin` | Creates a separate admin account and removes admin rights from your everyday account. See below. |

### `--separate-admin`

Moves you to a standard (non-admin) everyday account, with a separate account for admin tasks:

```bash
./05.Secure-Mac.py --separate-admin --new-admin localadmin
```

1. Shows the plan and asks you to type `YES`.
2. Creates the admin account (or reuses it if it exists). You're asked for its password, and for your own so it gets a **Secure Token** — without one it couldn't install macOS updates or unlock FileVault.
3. You type the new account's password again to prove it works.
4. Only then removes your account from the admin group. Any failed check stops before this point, leaving your account unchanged.

Afterwards, `sudo` no longer works from your account; macOS asks for the admin account's name and password instead. Options: `--new-admin NAME` (otherwise you're asked), `--demote-user NAME` (default: you). To undo, log in as the admin account and run `./05.Secure-Mac.py --separate-admin --demote-user YOURNAME --restore-defaults`. The admin account is never deleted automatically.

> Some categories that exist on Windows/Fedora are deliberately absent: macOS protects camera/mic blocking and Bonjour/mDNS behind System Integrity Protection, so they can't be safely scripted.

---

## MacSystemInfo.py — system information

Prints hardware, software, storage, power and display details using `system_profiler`.

```bash
./MacSystemInfo.py --run
```

---

## Terminal/

Shell configuration installed by `02.Configure-Mac.py` — not run directly:

| File | What it is |
|---|---|
| `.zshrc` | Custom prompt (user, host, time, folder) that loads every alias file below. |
| `.bash_aliases/` | Aliases grouped by topic: `base`, `cleanup`, `diagnostics`, `docker`, `git`, `safety` (`rm` asks before deleting, `cp`/`mv` before overwriting), and `unix` (modern tools like `eza`/`bat`, only used if installed). |
| `Microsoft.PowerShell_profile.ps1` | PowerShell prompt showing date, last command's run time, user and folder. |
| `PowerShell.terminal` | A Terminal.app profile named "PowerShell". |
