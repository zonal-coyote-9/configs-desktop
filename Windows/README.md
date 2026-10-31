# Windows

PowerShell scripts for setting up, configuring, updating and hardening Windows 11. They're numbered in the order you'd run them on a new machine:

| Step | Script | When to run it | Run as |
|---|---|---|---|
| 1 | [01.Setup-Windows.ps1](01.Setup-Windows.ps1) | Once, right after a fresh Windows install | Administrator recommended |
| 2 | [02.Configure-Windows.ps1](02.Configure-Windows.ps1) | Once, after setup | Your normal user |
| 4 | [04.Update-Windows.ps1](04.Update-Windows.ps1) | Any time, for recurring updates | Administrator |
| 5 | [05.Secure-Windows.ps1](05.Secure-Windows.ps1) | Any time after setup (optional) | Administrator |
| – | [New-EdgeProfile.ps1](New-EdgeProfile.ps1) | Any time | Your normal user |

## Before you start

If Windows blocks the scripts, run this once in PowerShell:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Files downloaded from the internet may also need unblocking:

```powershell
Unblock-File .\01.Setup-Windows.ps1
```

To open an Administrator PowerShell: right-click **Terminal** (or PowerShell) › **Run as administrator**.

All scripts are safe to re-run: steps that are already done are skipped or re-applied with the same result. Running any script with no parameters just shows its help — nothing changes until you pass `-Run` (or the script's own parameters). Run `Get-Help .\<script>.ps1 -Full` for the complete built-in help.

---

## 01.Setup-Windows.ps1 — first-run setup

1. Offers to rename the PC (see `-MachineName` below). Renaming needs an Administrator shell and takes effect after a restart.
2. Asks which apps you want from a menu per category — Comms, Media, Office Apps, Utilities, Dev, Creative, Others and AI — then installs them with `winget`. Any failures are reported as warnings.
3. Runs some environment-specific steps (see the note below).

```powershell
.\01.Setup-Windows.ps1 -Run                                  # asks for everything
.\01.Setup-Windows.ps1 -InstallAll                           # no app menus - install every app
.\01.Setup-Windows.ps1 -MachineName WORKSTATION-01 -InstallAll   # no prompts at all
.\01.Setup-Windows.ps1 -Run -SkipPostInstallSteps            # stop after the app installs
```

| Parameter | What it does |
|---|---|
| `-Run` | Runs setup, asking for anything not given on the command line. Not needed when `-MachineName` or `-InstallAll` is given. |
| `-MachineName NAME` | Renames the PC, even if it was renamed before (letters, digits, hyphens; max 15 characters). Without it, you're only asked while the PC still has its default `DESKTOP-XXXXXXX` / `LAPTOP-XXXXXXX` name. |
| `-InstallAll` | Skips the app menus and installs every app in every category. |
| `-SkipPostInstallSteps` | Stops after the app installs, skipping the environment-specific steps below. |

**Menu keys:** `A` = all apps in the category, `S` or Enter = skip it, `Q` = quit without installing anything, or numbers such as `1,3`.

> **Environment-specific steps:** after the apps, the script runs a Windows Terminal setup script and imports a CA certificate from folders *outside* this repo (`..\..\Apps\Terminal\Win\TermSetup.ps1` and `..\..\Tech\PKI\NativemodeIssuingCA.cer`). It also installs DoD certificates by running a script downloaded from GitHub, and maps `S:` to `\\ds.nativehome.net\dfs`. These suit the author's own home network. On any other machine, use `-SkipPostInstallSteps`.

When it finishes, run `02.Configure-Windows.ps1 -Run`.

---

## 02.Configure-Windows.ps1 — preference settings

Applies preferences for your account (no Administrator rights needed):

- 24-hour time across Windows, including the taskbar clock.
- File extensions always shown in File Explorer (also helps you spot disguised files like `invoice.pdf.exe`).

```powershell
.\02.Configure-Windows.ps1 -Run
```

No other parameters. Sign out and back in to see the changes everywhere.

---

## 04.Update-Windows.ps1 — recurring updates

Installs pending Windows Update updates, triggers Microsoft Store app updates, and upgrades every app `winget` manages. (It runs the three update categories of `05.Secure-Windows.ps1`, so that script must be in the same folder.)

```powershell
.\04.Update-Windows.ps1 -Run      # install updates
.\04.Update-Windows.ps1 -Report   # just show what's pending
```

Some Windows updates need a restart to finish; the script tells you if one is needed.

---

## 05.Secure-Windows.ps1 — security hardening (optional)

Applies reversible security settings in independent categories. Run it from an Administrator PowerShell. Each category has three modes:

- **Harden** (default): applies the settings.
- **`-Report`**: changes nothing; prints a table of each setting's expected and actual value, with mismatches listed at the end.
- **`-RestoreDefaults`**: puts the selected categories back to Windows' out-of-box settings.

```powershell
.\05.Secure-Windows.ps1 -All -Report        # see what would change - start here
.\05.Secure-Windows.ps1 -All                # apply every standard category
.\05.Secure-Windows.ps1 -Defender -Firewall -Smb -Uac
.\05.Secure-Windows.ps1 -Uac -Rdp -RestoreDefaults
```

| Category | What hardening does |
|---|---|
| `-Defender` | Real-time and cloud protection, blocking of potentially unwanted apps, Controlled Folder Access (ransomware protection), and attack-surface reduction rules. Controlled Folder Access can block apps from saving to Documents/Pictures until you allow them. |
| `-Firewall` | Firewall on for all network types, incoming connections blocked by default, dropped connections logged. |
| `-BitLocker` | Turns on drive encryption (needs a TPM). **Back up the recovery key.** Restore decrypts the drive (slow; warns first). |
| `-Smb` | Turns off the outdated SMBv1 file-sharing protocol and requires signed SMB connections. |
| `-NetworkDiscovery` | Turns off LLMNR and NetBIOS name discovery. |
| `-Uac` | UAC set to "Always notify". |
| `-Services` | Disables the Remote Registry and Windows Media Player network sharing services. |
| `-Rdp` | Turns Remote Desktop off. With `-KeepRdp`, keeps it on but requires Network Level Authentication. |
| `-Ssh` | Turns the OpenSSH Server off, if installed. With `-KeepSsh`, keeps it on but hardened: key-only sign-in if keys are set up (add `-KeepPasswordAuth` to keep passwords). |
| `-Lockscreen` | Locks after 10 minutes idle, password required when waking from sleep, automatic sign-in off, AutoPlay/AutoRun off. |
| `-Audit` | Logs successful and failed sign-ins, account changes and use of special privileges. |
| `-CredentialHardening` | Passwords must be 14+ characters and meet complexity rules (3 of 4 character types); 15-minute lockout after 10 wrong attempts; Guest account off; older, weaker sign-in protocols (LM/NTLMv1) refused; anonymous account listing blocked; `.vbs`/`.js` scripts blocked. |
| `-AttackSurfaceExtras` | Blocks connections to known-malicious sites (Defender Network Protection), removes PowerShell 2.0, turns on PowerShell logging, turns off mDNS and Remote Assistance. |
| `-Privacy` | Diagnostic data reduced to the minimum, ads and suggestions off, activity history, Recall, web search in Start, Cortana and Copilot off, recent-documents history off. |
| `-Edge` | Microsoft Edge security/privacy policies (SmartScreen, tracking prevention, third-party cookies blocked, telemetry off, etc.). |
| `-Sysmon` | Installs Microsoft Sysmon with the widely used SwiftOnSecurity configuration (downloads from Microsoft/GitHub). |
| `-WindowsUpdate` / `-StoreApps` / `-WingetUpdate` | Installs pending updates (what `04.Update-Windows.ps1` runs). |

**Opt-in categories** — not included in `-All`; you must name them:

| Category | What it does |
|---|---|
| `-PrivacyStrict` | Turns off location services and blocks camera and microphone for all apps — **breaks Teams, Zoom and other video apps** until restored. |
| `-EdgeStrict` | Stricter Edge policies, including HTTPS-only mode (**breaks plain-HTTP sites**) and no clicking through certificate warnings (**blocks self-signed internal sites** unless their root certificate is trusted). |
| `-SeparateAdmin` | Creates a separate admin account and removes admin rights from your everyday account. See below. |

### `-SeparateAdmin`

Moves you to a standard (non-admin) everyday account, with a separate account for admin tasks:

```powershell
.\05.Secure-Windows.ps1 -SeparateAdmin -NewAdminName localadmin
```

1. Shows the plan and asks you to type `YES`.
2. Creates the local admin account (or reuses it). You type its password twice. It's set never to expire, because an expired password can't be used at a UAC prompt.
3. Checks the account is an enabled administrator and that its password really works.
4. Only then removes your account from Administrators. Any failed check stops before this point, leaving your account unchanged.

By default it demotes the user signed in at the console — even if you started the Administrator window with another account. Afterwards, UAC prompts ask for the admin account's name and password. Sign out and back in to finish. Parameters: `-NewAdminName NAME` (otherwise you're asked), `-DemoteUser NAME`. To undo, from the admin account: `.\05.Secure-Windows.ps1 -SeparateAdmin -DemoteUser YOURNAME -RestoreDefaults`. The admin account is never deleted automatically.

---

## New-EdgeProfile.ps1 — Edge profiles

Opens Microsoft Edge once per profile name, creating a separate Edge profile for each. The defaults are Personal, School, ADM-CCE, ADM-TPM and ADM-Nativemode.

```powershell
.\New-EdgeProfile.ps1 -Run                        # the default list
.\New-EdgeProfile.ps1 -Profiles Work, Banking     # your own list
```

Each profile opens in its own Edge window; rename or customize them at `edge://settings/profiles`.

---

## Terminal/

Windows Terminal and PowerShell configuration — not run directly:

| File | What it is |
|---|---|
| `TermSetup.ps1` | Replaces Windows Terminal's settings folder with a link to `%OneDriveConsumer%\Apps\Terminal\Win`, so Terminal settings sync through OneDrive. Called automatically by `01.Setup-Windows.ps1`; to run it yourself, use `.\TermSetup.ps1 -Run`. **It deletes the existing settings folder first** — only run it once OneDrive is installed and syncing. |
| `settings.json`, `state.json`, `elevated-state.json`, `Microsoft_logo_azure.png` | Windows Terminal settings and assets. |
| `Microsoft.PowerShell_profile.ps1` | PowerShell prompt showing date, last command's run time, user and folder. It also loads tools from `C:\Tools` and `C:\CeiseData`, which only exist on the author's work machines — remove those lines before using it elsewhere. |
| `MyFunctions.ps1` | `Get-ExternalIP` (shows your public IP address). It also tries to load function files from a `Functions\` folder that isn't part of this repo, so those lines fail unless you provide the files. |
