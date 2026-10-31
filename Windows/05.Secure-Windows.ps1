<#
.SYNOPSIS
    Applies reasonable, reversible security hardening to a Windows 11 laptop -
    or reverts any of the same categories back to Windows out-of-box defaults -
    or reports Expected vs Found state for every setting it manages.

.DESCRIPTION
    Runs a set of independent hardening categories. Pick specific switches or use -All.
    Every category is written to be idempotent - safe to re-run.
    Add -RestoreDefaults to the same switches to undo them back to Windows' stock settings,
    instead of hardening. Add -Report to print a table of Expected vs Found state for every
    setting this script manages, with no changes made.
    The three update categories (-WindowsUpdate, -StoreApps, -WingetUpdate) are one-way
    actions - there's no "default" to revert an install back to, so -RestoreDefaults is a
    no-op for them, and -Report lists what's pending instead of an expected/found table.
    Must be run from an elevated (Administrator) PowerShell session.
    Running with no parameters shows this help and changes nothing.

.PARAMETER All
    Run every hardening (or, with -RestoreDefaults, every default-restore) category below,
    EXCEPT -PrivacyStrict, -EdgeStrict and -SeparateAdmin, which are opt-in only - the first
    two can break camera/microphone apps, plain-HTTP intranet pages, or self-signed internal
    sites, and the last changes which account can approve admin prompts.

.PARAMETER Defender
    Harden: real-time protection, cloud-delivered protection, PUA blocking,
    Controlled Folder Access, and a baseline set of ASR rules (LSASS rule in audit mode).
    Restore: PUA protection off, Controlled Folder Access off, MAPS reporting Basic,
    sample submission "Send safe samples", and the ASR rules removed (not configured).

.PARAMETER Firewall
    Harden: Windows Firewall enabled on all 3 profiles, inbound blocked by default, and
    dropped-packet logging turned on with the log file size raised to 16 MB (from the
    4 MB default) so it doesn't roll over too quickly.
    Restore: enabled/inbound-block state matches stock Windows 11 already (included for
    completeness); logging reverted to off with the default 4 MB size cap.

.PARAMETER BitLocker
    Harden: enables BitLocker on the OS drive using TPM, if present and not already on.
    Restore: DECRYPTS the OS drive (Disable-BitLocker). This takes time and leaves the
    disk unencrypted - the script prints a warning before doing it.

.PARAMETER Smb
    Harden: disables SMBv1 (client + server), requires SMB signing.
    Restore: SMBv1 left disabled (re-enabling a legacy, vulnerable protocol is not offered
    by this script even in restore mode); SMB signing requirement turned back off (stock default).

.PARAMETER NetworkDiscovery
    Harden: disables LLMNR and NetBIOS-over-TCP/IP on all adapters.
    Restore: re-enables LLMNR and sets NetBIOS back to "Default" (use DHCP setting).

.PARAMETER Uac
    Harden: UAC set to Always Notify (secure desktop).
    Restore: UAC set back to the Windows out-of-box default (notify only when apps try
    to make changes, non-Windows binaries prompt for consent).

.PARAMETER Services
    Harden: disables Remote Registry and WMP Network Sharing.
    Restore: sets both back to their stock startup type (Manual).

.PARAMETER Rdp
    Harden: disables inbound RDP entirely, OR with -KeepRdp, leaves RDP enabled but
    forces Network Level Authentication.
    Restore: sets RDP back to the Windows default (disabled, NLA required if ever enabled).

.PARAMETER KeepRdp
    Modifier for -Rdp: keep RDP enabled but require NLA, instead of disabling it. Also
    changes what -Report treats as "Expected" for RDP. Ignored in -RestoreDefaults mode.

.PARAMETER Ssh
    Skipped (with a note) if the optional OpenSSH Server feature isn't installed - which
    is Windows' default. Harden: stops and disables the sshd service and its firewall
    rule, OR with -KeepSsh, leaves it running and adds a hardened block to the top of
    C:\ProgramData\ssh\sshd_config (empty passwords off, X11 forwarding off,
    lower MaxAuthTries, idle client timeout, and password auth disabled UNLESS
    -KeepPasswordAuth is given or no authorized_keys file exists for any user, so you
    can't lock yourself out). Same design as the Mac/Fedora scripts' --ssh.
    Restore: hardening block removed, sshd set back to its default Manual startup type
    and stopped.

.PARAMETER KeepSsh
    Modifier for -Ssh: keep the OpenSSH Server enabled but hardened. Ignored in
    -RestoreDefaults mode.

.PARAMETER KeepPasswordAuth
    Modifier for -Ssh -KeepSsh: keep SSH password authentication enabled, but still apply
    every other SSH hardening item. Ignored in -RestoreDefaults mode.

.PARAMETER Lockscreen
    Harden: machine locks after 10 minutes of inactivity, a password is required when
    waking from sleep (AC + battery), automatic sign-in (AutoAdminLogon) is turned off if
    it was configured, and autorun/autoplay is disabled for all drive types - matching the
    Mac/Fedora scripts' --lockscreen.
    Restore: inactivity limit and password-on-wake policies removed (not configured),
    autorun/autoplay registry override removed so Windows' own default policy applies.
    Automatic sign-in is left disabled - re-enabling passwordless sign-in isn't offered.

.PARAMETER Audit
    Harden: enables success+failure auditing for logon, account management, and
    privilege use.
    Restore: turns that explicit auditing back off (stock non-domain-joined default).

.PARAMETER CredentialHardening
    Harden: NTLM restricted to NTLMv2-only (refuses LM/NTLMv1), anonymous SAM/share
    enumeration blocked, Windows Script Host disabled (blocks .vbs/.js execution), Guest
    account disabled, and local password/lockout policy raised (14-char minimum, password
    complexity required - 3 of 4 character types - and a 15-minute lockout after 10 bad
    attempts; the same baseline as the Mac/Fedora scripts).
    Restore: NTLM compatibility level un-set (falls back to the OS default behavior),
    anonymous-enumeration restriction relaxed to its default, Windows Script Host
    re-enabled, Guest account left disabled (that's the Windows default too), and
    password/lockout policy reset to the stock no-minimum/no-complexity/no-lockout values.

.PARAMETER AttackSurfaceExtras
    Harden: Defender Network Protection enabled (blocks outbound connections to known
    malicious domains/IPs), the legacy PowerShell 2.0 engine removed, PowerShell script
    block/module logging and transcription turned on, mDNS disabled, and Remote
    Assistance disabled.
    Restore: Network Protection off, PowerShell 2.0 engine reinstalled, PowerShell
    logging policies removed (unconfigured), mDNS and Remote Assistance back to their
    Windows defaults (both enabled).

.PARAMETER Privacy
    Harden: diagnostic data level lowered to Required/Basic, advertising ID disabled
    machine-wide, tailored experiences with diagnostic data disabled, Start menu
    suggestions/consumer features disabled, activity history feed/publish/upload all
    turned off, Windows Recall snapshot saving blocked, Start menu web search and
    Cortana disabled, inking/typing personalization disabled, Windows Copilot turned
    off, and recently-opened-documents history turned off (same as the Fedora
    script's recent-files setting).
    Restore: all of the above policy overrides removed, so Windows' own defaults
    (typically more permissive) apply again.

.PARAMETER PrivacyStrict
    NOT included in -All - opt in explicitly. Harden: disables location services
    machine-wide, force-denies camera and microphone access for all apps, and disables
    cross-device clipboard sync. The camera/microphone change WILL break Teams, Zoom,
    and any other app that needs them until you either revert this or grant per-app
    exceptions in Settings > Privacy. Restore: all three policies removed (unconfigured),
    handing camera/mic/location control back to the user's own per-app choices.

.PARAMETER Edge
    Harden: applies a set of Microsoft Edge browser policies via the registry -
    SmartScreen (site + PUA + trusted-download checks), third-party cookies blocked,
    Balanced tracking prevention, password leak detection, credit card autofill off,
    network prediction/prefetch off, alternate error pages off, shopping assistant off,
    personalization reporting off, feedback prompts off, Do Not Track header sent,
    metrics/diagnostic reporting off, Enhance Security Mode set to Balanced, and startup
    boost (background prelaunch) off. None of these should meaningfully change your
    day-to-day browsing.
    Restore: all of the above policies removed (unconfigured), Edge's own defaults apply.

.PARAMETER EdgeStrict
    NOT included in -All - opt in explicitly. Harden: escalates tracking prevention to
    Strict and Enhance Security Mode to Strict, disables Edge sign-in and account sync, disables the
    built-in password manager, disables search-suggest-while-typing, blocks bypassing
    SSL certificate warnings, and forces HTTPS-Only mode. Two of these are worth knowing
    about given your homelab: HTTPS-Only mode will break any plain-HTTP intranet page you
    browse to (including your own PKI CDP/AIA base URL at
    http://pki.nativehome.net/pki/), and blocking cert-warning bypass will block access
    to self-signed internal sites unless your Nativehome-Root-CA-5 root is trusted on
    this machine. Restore: all of the above removed (unconfigured), including HTTPS-Only
    mode.

.PARAMETER Sysmon
    Downloads Sysinternals Sysmon (official Microsoft download) and the widely-used
    SwiftOnSecurity baseline configuration from GitHub, then installs Sysmon with that
    config (or re-applies the config if Sysmon is already installed). Gives you real
    process/network/registry telemetry in the Sysmon event log beyond what Defender
    alone logs - useful for both defense and your own investigation work.
    Restore: uninstalls Sysmon entirely (no Sysmon = the Windows default, since it isn't
    a built-in component). Report mode just checks whether the service is installed and
    running; it doesn't diff the applied config line-by-line.
    NOTE: this downloads and executes an installer from the internet. Review
    $sysmonZipUrl / $sysmonConfigUrl below before running if you want to verify them
    yourself first, and expect this section to need updating if either URL ever moves.

.PARAMETER SeparateAdmin
    NOT included in -All - opt in explicitly. Always runs last. Harden: creates a separate
    local admin account (-NewAdminName, or you're asked for one), then removes the signed-in
    user (or -DemoteUser) from the local Administrators group, so day-to-day work happens in a
    standard account and UAC prompts ask for the admin account's password. Safety checks, in
    order - any failure stops BEFORE your account is demoted:
      1. you type YES to confirm the plan;
      2. you type the new account's password twice and they must match;
      3. the account must exist, be enabled and be in Administrators;
      4. its password must actually authenticate (checked against the local SAM).
    If the admin account already exists it's reused (checks 3-4 still apply). The new account's
    password is set not to expire - an expired password can't be used at a UAC prompt, which
    would leave you with no working admin. Your current elevated window keeps its rights until
    closed; sign out and back in for the change to take full effect.
    Report: shows whether the user is in Administrators, and whether a separate admin account
    exists. Restore: adds -DemoteUser back to Administrators - run it from the admin account,
    e.g. .\05.Secure-Windows.ps1 -SeparateAdmin -DemoteUser alice -RestoreDefaults. The admin
    account is left in place - deleting accounts isn't offered.

.PARAMETER NewAdminName
    Modifier for -SeparateAdmin: name of the local admin account to create or reuse.

.PARAMETER DemoteUser
    Modifier for -SeparateAdmin: the account to remove from (or, on restore, add back to)
    Administrators. Default: the user signed in at the console.

.PARAMETER WindowsUpdate
    Searches Windows Update for software updates, downloads and installs anything pending
    via the built-in Microsoft.Update COM API (no external module required). May require
    a reboot to finish - the script tells you if one is needed. Report mode adds a single
    pending-count row to the same Expected/Found table as every other category, instead
    of installing. Not affected by -RestoreDefaults.

.PARAMETER StoreApps
    Triggers the Microsoft Store to scan for and install updates to installed Store apps
    (same mechanism as clicking "Get updates" in the Store app). Report mode adds a single
    row confirming the scan was triggered - the Store doesn't expose a synchronous
    "what's pending" list to script, so that's the most this can report. Not affected by
    -RestoreDefaults.

.PARAMETER WingetUpdate
    Runs 'winget upgrade --all' to update every app winget manages (skipped if winget
    isn't installed). Report mode adds a single pending-count row (parsed from 'winget
    upgrade' output - an approximation, since winget's console output isn't structured
    data) to the same table as everything else, instead of installing. Not affected by
    -RestoreDefaults.

.PARAMETER RestoreDefaults
    Reverts the selected categories to Windows out-of-box defaults instead of hardening
    them. Combine with -All or specific category switches, same as normal use.
    Cannot be combined with -Report.

.PARAMETER Report
    For each selected category, prints a table with one row per setting: Category,
    Setting, Expected (the value this script's hardening would set), Found (the value
    actually on this machine right now), and Status (OK / MISMATCH). Makes no changes.
    Cannot be combined with -RestoreDefaults.

.EXAMPLE
    .\05.Secure-Windows.ps1 -All

.EXAMPLE
    .\05.Secure-Windows.ps1 -Defender -Firewall -Smb -Uac

.EXAMPLE
    .\05.Secure-Windows.ps1 -All -Report
    Prints an Expected vs Found table for every setting, changes nothing.

.EXAMPLE
    .\05.Secure-Windows.ps1 -Uac -Rdp -RestoreDefaults
    Reverts just UAC and RDP settings back to stock Windows 11 defaults.

.EXAMPLE
    .\05.Secure-Windows.ps1 -All -RestoreDefaults
    Reverts everything this script can touch back to stock Windows 11 defaults.

.EXAMPLE
    .\05.Secure-Windows.ps1 -Ssh -KeepSsh
    Keeps the OpenSSH Server running but hardened (key-based auth only if keys exist).

.EXAMPLE
    .\05.Secure-Windows.ps1 -SeparateAdmin -NewAdminName localadmin
    Creates 'localadmin' as an administrator and makes the signed-in user a standard user.

.EXAMPLE
    .\05.Secure-Windows.ps1 -WindowsUpdate -StoreApps -WingetUpdate
    Installs all pending Windows Update, Microsoft Store, and winget-managed app updates.
#>

[CmdletBinding()]
param(
    [switch]$All,
    [switch]$Defender,
    [switch]$Firewall,
    [switch]$BitLocker,
    [switch]$Smb,
    [switch]$NetworkDiscovery,
    [switch]$Uac,
    [switch]$Services,
    [switch]$Rdp,
    [switch]$KeepRdp,
    [switch]$Ssh,
    [switch]$KeepSsh,
    [switch]$KeepPasswordAuth,
    [switch]$Lockscreen,
    [switch]$Audit,
    [switch]$CredentialHardening,
    [switch]$AttackSurfaceExtras,
    [switch]$Privacy,
    [switch]$PrivacyStrict,
    [switch]$Edge,
    [switch]$EdgeStrict,
    [switch]$Sysmon,
    [switch]$WindowsUpdate,
    [switch]$StoreApps,
    [switch]$WingetUpdate,
    [switch]$SeparateAdmin,
    [string]$NewAdminName,
    [string]$DemoteUser,
    [switch]$RestoreDefaults,
    [switch]$Report
)

#region Setup

if ($PSBoundParameters.Count -eq 0) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Re-launch PowerShell elevated."
    exit 1
}

if ($Report -and $RestoreDefaults) {
    Write-Error "-Report and -RestoreDefaults cannot be combined - pick one."
    exit 1
}

if ($All) {
    $Defender = $Firewall = $BitLocker = $Smb = $NetworkDiscovery = $Uac = $Services = $Rdp = $Ssh = $Lockscreen = $Audit = $true
    $CredentialHardening = $AttackSurfaceExtras = $Privacy = $true
    $Edge = $true
    $Sysmon = $true
    $WindowsUpdate = $StoreApps = $WingetUpdate = $true
}

if (-not ($Defender -or $Firewall -or $BitLocker -or $Smb -or $NetworkDiscovery -or $Uac -or $Services -or $Rdp -or $Ssh -or $Lockscreen -or $Audit -or $CredentialHardening -or $AttackSurfaceExtras -or $Privacy -or $PrivacyStrict -or $Edge -or $EdgeStrict -or $Sysmon -or $WindowsUpdate -or $StoreApps -or $WingetUpdate -or $SeparateAdmin)) {
    Write-Host "No categories selected. Use -All or specific switches. Run with -? for help." -ForegroundColor Yellow
    exit 0
}

$mode = if ($Report) { "Report" } elseif ($RestoreDefaults) { "RestoreDefaults" } else { "Harden" }

# Action log, used in Harden / RestoreDefaults modes.
$results = [System.Collections.Generic.List[object]]::new()
function Log($Category, $Action, $Status) {
    $results.Add([pscustomobject]@{ Category = $Category; Action = $Action; Status = $Status })
    Write-Host "[$Category] $Action -> $Status"
}

# Expected-vs-Found log, used in Report mode.
$reportResults = [System.Collections.Generic.List[object]]::new()
function Add-ReportRow($Category, $Setting, $Expected, $Found) {
    $status = if ("$Expected" -eq "$Found") { "OK" } else { "MISMATCH" }
    $reportResults.Add([pscustomobject]@{
        Category = $Category
        Setting  = $Setting
        Expected = $Expected
        Found    = $Found
        Status   = $status
    })
}

#endregion

#region Defender
if ($Defender) {
    $prefs = Get-MpPreference

    $mapsMap  = @{0="Disabled"; 1="Basic"; 2="Advanced"}
    $sampMap  = @{0="AlwaysPrompt"; 1="SendSafeSamples"; 2="NeverSend"; 3="SendAllSamples"}
    $puaMap   = @{0="Disabled"; 1="Enabled"; 2="AuditMode"}
    $cfaMap   = @{0="Disabled"; 1="Enabled"; 2="AuditMode"; 3="BlockDiskModificationOnly"}
    $asrMap   = @{0="Disabled"; 1="Enabled"; 2="AuditMode"; 6="Warn"}
    $asrNames = @{
        "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" = "ASR: Block credential theft from LSASS"
        "d4f940ab-401b-4efc-aadc-ad5f3c50688a" = "ASR: Block Office child processes"
        "5beb7efe-fd9a-4556-801d-275e5ffc04cc" = "ASR: Block obfuscated scripts"
        "3b576869-a4ec-4529-8536-b80a7769e899" = "ASR: Block Office creating executables"
    }

    if ($mode -eq "Report") {
        Add-ReportRow "Defender" "Real-time protection" "Enabled" $(if ($prefs.DisableRealtimeMonitoring) {"Disabled"} else {"Enabled"})
        Add-ReportRow "Defender" "Cloud-delivered protection (MAPS)" "Advanced" $mapsMap[[int]$prefs.MAPSReporting]
        Add-ReportRow "Defender" "Sample submission" "SendAllSamples" $sampMap[[int]$prefs.SubmitSamplesConsent]
        Add-ReportRow "Defender" "PUA protection" "Enabled" $puaMap[[int]$prefs.PUAProtection]
        Add-ReportRow "Defender" "Controlled Folder Access" "Enabled" $cfaMap[[int]$prefs.EnableControlledFolderAccess]

        $asrExpected = @{
            "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" = "AuditMode"
            "d4f940ab-401b-4efc-aadc-ad5f3c50688a" = "Enabled"
            "5beb7efe-fd9a-4556-801d-275e5ffc04cc" = "Enabled"
            "3b576869-a4ec-4529-8536-b80a7769e899" = "Enabled"
        }
        $asrIdsFound = @($prefs.AttackSurfaceReductionRules_Ids)
        $asrActionsFound = @($prefs.AttackSurfaceReductionRules_Actions)
        foreach ($id in $asrExpected.Keys) {
            $idx = [array]::IndexOf($asrIdsFound, $id)
            $found = if ($idx -ge 0) { $asrMap[[int]$asrActionsFound[$idx]] } else { "NotConfigured" }
            Add-ReportRow "Defender" $asrNames[$id] $asrExpected[$id] $found
        }
    }
    elseif ($mode -eq "RestoreDefaults") {
        Set-MpPreference -PUAProtection Disabled
        Set-MpPreference -EnableControlledFolderAccess Disabled
        Set-MpPreference -MAPSReporting Basic
        Set-MpPreference -SubmitSamplesConsent SendSafeSamples
        $asrIds = @(
            "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2",
            "d4f940ab-401b-4efc-aadc-ad5f3c50688a",
            "5beb7efe-fd9a-4556-801d-275e5ffc04cc",
            "3b576869-a4ec-4529-8536-b80a7769e899"
        )
        Remove-MpPreference -AttackSurfaceReductionRules_Ids $asrIds -ErrorAction SilentlyContinue
        Log "Defender" "PUA protection, Controlled Folder Access, MAPS/sample reporting, ASR rules" "Reverted to Windows defaults (real-time protection left ON - never disable it)"
    }
    else {
        Set-MpPreference -DisableRealtimeMonitoring $false
        Log "Defender" "Real-time protection" "Enabled"

        Set-MpPreference -MAPSReporting Advanced
        Set-MpPreference -SubmitSamplesConsent SendAllSamples
        Log "Defender" "Cloud-delivered protection" "Enabled (advanced)"

        Set-MpPreference -PUAProtection Enabled
        Log "Defender" "Potentially Unwanted App blocking" "Enabled"

        Set-MpPreference -EnableControlledFolderAccess Enabled
        Log "Defender" "Controlled Folder Access (ransomware protection)" "Enabled"

        $asrRules = @{
            "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" = "AuditMode" # Block credential stealing from LSASS - audit first
            "d4f940ab-401b-4efc-aadc-ad5f3c50688a" = "Enabled"   # Block Office apps from creating child processes
            "5beb7efe-fd9a-4556-801d-275e5ffc04cc" = "Enabled"   # Block execution of potentially obfuscated scripts
            "3b576869-a4ec-4529-8536-b80a7769e899" = "Enabled"   # Block Office apps from creating executable content
        }
        foreach ($rule in $asrRules.GetEnumerator()) {
            Add-MpPreference -AttackSurfaceReductionRules_Ids $rule.Key -AttackSurfaceReductionRules_Actions $rule.Value
        }
        Log "Defender" "Baseline ASR rules" "Applied (LSASS rule set to audit mode - review before enforcing)"
    }
}
#endregion

#region Firewall
if ($Firewall) {
    $fwLogPath = "%systemroot%\system32\LogFiles\Firewall\pfirewall.log"
    $fwLogMaxKb = 16384

    if ($mode -eq "Report") {
        foreach ($p in Get-NetFirewallProfile) {
            Add-ReportRow "Firewall" "$($p.Name) profile enabled" "True" $p.Enabled
            Add-ReportRow "Firewall" "$($p.Name) profile default inbound action" "Block" $p.DefaultInboundAction
            Add-ReportRow "Firewall" "$($p.Name) profile log dropped packets" "True" $p.LogBlocked
            Add-ReportRow "Firewall" "$($p.Name) profile log max size (KB)" "$fwLogMaxKb" $p.LogMaxSizeKilobytes
        }
    }
    elseif ($mode -eq "RestoreDefaults") {
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow
        Log "Firewall" "All profiles" "Reverted to Windows defaults (enabled, inbound blocked)"

        Set-NetFirewallProfile -Profile Domain,Public,Private -LogBlocked False -LogMaxSizeKilobytes 4096
        Log "Firewall" "Logging" "Reverted to Windows defaults (dropped-packet logging off, 4096 KB max size)"
    }
    else {
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow
        Log "Firewall" "All profiles enabled, inbound blocked by default" "Done"

        Set-NetFirewallProfile -Profile Domain,Public,Private -LogBlocked True -LogFileName $fwLogPath -LogMaxSizeKilobytes $fwLogMaxKb
        Log "Firewall" "Logging (dropped packets, $fwLogMaxKb KB max)" "Enabled at $fwLogPath"
    }
}
#endregion

#region BitLocker
if ($BitLocker) {
    $osVol = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue
    $tpm = Get-Tpm -ErrorAction SilentlyContinue

    if ($mode -eq "Report") {
        if (-not $tpm -or -not $tpm.TpmPresent) {
            Add-ReportRow "BitLocker" "$env:SystemDrive protection status" "On" "N/A - no TPM detected"
        } else {
            $found = if ($osVol) { $osVol.ProtectionStatus } else { "Unknown" }
            Add-ReportRow "BitLocker" "$env:SystemDrive protection status" "On" $found
        }
    }
    elseif ($mode -eq "RestoreDefaults") {
        if (-not $osVol -or $osVol.VolumeStatus -eq 'FullyDecrypted') {
            Log "BitLocker" "Disable on $env:SystemDrive" "Already off / not encrypted"
        } else {
            Write-Host "WARNING: about to DECRYPT $env:SystemDrive. The disk will be unprotected once this completes. Ctrl+C now to cancel." -ForegroundColor Red
            Start-Sleep -Seconds 5
            Disable-BitLocker -MountPoint $env:SystemDrive | Out-Null
            Log "BitLocker" "Disable on $env:SystemDrive" "Decryption started - check 'manage-bde -status' for progress"
        }
    }
    else {
        if (-not $tpm -or -not $tpm.TpmPresent) {
            Log "BitLocker" "Enable on $env:SystemDrive" "Skipped - no TPM detected"
        } elseif ($osVol -and $osVol.ProtectionStatus -eq 'On') {
            Log "BitLocker" "Enable on $env:SystemDrive" "Already enabled"
        } else {
            Enable-BitLocker -MountPoint $env:SystemDrive -TpmProtector -UsedSpaceOnly -SkipHardwareTest -ErrorAction Stop
            Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -RecoveryPasswordProtector | Out-Null
            Log "BitLocker" "Enable on $env:SystemDrive" "Enabled with TPM protector + recovery password (BACK UP the recovery key: manage-bde -protectors -get $env:SystemDrive)"
        }
    }
}
#endregion

#region SMB
if ($Smb) {
    if ($mode -eq "Report") {
        $srvCfg = Get-SmbServerConfiguration
        $cliCfg = Get-SmbClientConfiguration
        Add-ReportRow "SMB" "SMBv1 protocol enabled" "False" $srvCfg.EnableSMB1Protocol
        Add-ReportRow "SMB" "Server requires signing" "True" $srvCfg.RequireSecuritySignature
        Add-ReportRow "SMB" "Client requires signing" "True" $cliCfg.RequireSecuritySignature
    }
    elseif ($mode -eq "RestoreDefaults") {
        Set-SmbServerConfiguration -RequireSecuritySignature $false -Force
        Set-SmbClientConfiguration -RequireSecuritySignature $false -Force
        Log "SMB" "Signing requirement" "Reverted to Windows default (not required)"
        Log "SMB" "SMBv1" "Left disabled - re-enabling a legacy, vulnerable protocol isn't offered by this script"
    }
    else {
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Log "SMB" "SMBv1 disabled (client + server)" "Done"

        Set-SmbServerConfiguration -RequireSecuritySignature $true -Force
        Set-SmbClientConfiguration -RequireSecuritySignature $true -Force
        Log "SMB" "SMB signing required" "Done"
    }
}
#endregion

#region NetworkDiscovery (LLMNR/NetBIOS)
if ($NetworkDiscovery) {
    $dnsClientKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"

    if ($mode -eq "Report") {
        $llmnr = Get-ItemProperty -Path $dnsClientKey -Name EnableMulticast -ErrorAction SilentlyContinue
        $llmnrFound = if ($null -eq $llmnr) { "Enabled (not configured)" } elseif ($llmnr.EnableMulticast -eq 0) { "Disabled" } else { "Enabled" }
        Add-ReportRow "Network" "LLMNR" "Disabled" $llmnrFound

        $nbtMap = @{0="Default (use DHCP)"; 1="Enabled"; 2="Disabled"}
        Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" | ForEach-Object {
            $opt = $_.TcpipNetbiosOptions
            $foundText = if ($null -eq $opt) { "Default (use DHCP)" } else { $nbtMap[[int]$opt] }
            Add-ReportRow "Network" "NetBIOS over TCP/IP ($($_.Description))" "Disabled" $foundText
        }
    }
    elseif ($mode -eq "RestoreDefaults") {
        if (Test-Path $dnsClientKey) {
            Remove-ItemProperty -Path $dnsClientKey -Name EnableMulticast -ErrorAction SilentlyContinue
        }
        Log "Network" "LLMNR" "Reverted to Windows default (enabled)"

        Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" | ForEach-Object {
            $_ | Invoke-CimMethod -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = 0 } | Out-Null
        }
        Log "Network" "NetBIOS over TCP/IP" "Reverted to Windows default (use DHCP setting) on all adapters"
    }
    else {
        if (-not (Test-Path $dnsClientKey)) { New-Item -Path $dnsClientKey -Force | Out-Null }
        Set-ItemProperty -Path $dnsClientKey -Name EnableMulticast -Value 0 -Type DWord
        Log "Network" "LLMNR disabled" "Done"

        Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" | ForEach-Object {
            $_ | Invoke-CimMethod -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = 2 } | Out-Null
        }
        Log "Network" "NetBIOS over TCP/IP disabled on all adapters" "Done"
    }
}
#endregion

#region UAC
if ($Uac) {
    $uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

    if ($mode -eq "Report") {
        $vals = Get-ItemProperty -Path $uacKey -Name ConsentPromptBehaviorAdmin, PromptOnSecureDesktop -ErrorAction SilentlyContinue
        Add-ReportRow "UAC" "ConsentPromptBehaviorAdmin (2 = Always Notify)" "2" $vals.ConsentPromptBehaviorAdmin
        Add-ReportRow "UAC" "PromptOnSecureDesktop" "1" $vals.PromptOnSecureDesktop
    }
    elseif ($mode -eq "RestoreDefaults") {
        Set-ItemProperty -Path $uacKey -Name ConsentPromptBehaviorAdmin -Value 5 -Type DWord
        Set-ItemProperty -Path $uacKey -Name PromptOnSecureDesktop -Value 1 -Type DWord
        Log "UAC" "Prompt behavior" "Reverted to Windows default (notify only on app changes, secure desktop on)"
    }
    else {
        Set-ItemProperty -Path $uacKey -Name ConsentPromptBehaviorAdmin -Value 2 -Type DWord
        Set-ItemProperty -Path $uacKey -Name PromptOnSecureDesktop -Value 1 -Type DWord
        Log "UAC" "Set to Always Notify (secure desktop)" "Done"
    }
}
#endregion

#region Services
if ($Services) {
    $servicesToDisable = @('RemoteRegistry', 'WMPNetworkSvc')
    foreach ($svcName in $servicesToDisable) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if (-not $svc) { continue }

        if ($mode -eq "Report") {
            Add-ReportRow "Services" "$svcName startup type" "Disabled" $svc.StartType
        }
        elseif ($mode -eq "RestoreDefaults") {
            Set-Service -Name $svcName -StartupType Manual
            Log "Services" "$svcName" "Reverted to Windows default startup type (Manual)"
        }
        else {
            Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svcName -StartupType Disabled
            Log "Services" "$svcName disabled" "Done"
        }
    }
}
#endregion

#region RDP
if ($Rdp) {
    $rdpKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    $nlaKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"

    if ($mode -eq "Report") {
        $deny = (Get-ItemProperty -Path $rdpKey -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections
        $nla  = (Get-ItemProperty -Path $nlaKey -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication
        $expectedDeny = if ($KeepRdp) { "0 (enabled)" } else { "1 (disabled)" }
        $foundDeny = if ($null -eq $deny) { "Unknown" } elseif ($deny -eq 1) { "1 (disabled)" } else { "0 (enabled)" }
        Add-ReportRow "RDP" "Inbound connections" $expectedDeny $foundDeny
        if ($KeepRdp) {
            $foundNla = if ($null -eq $nla) { "Unknown" } else { $nla }
            Add-ReportRow "RDP" "Network Level Authentication required" "1" $foundNla
        }
    }
    elseif ($mode -eq "RestoreDefaults") {
        Set-ItemProperty -Path $rdpKey -Name fDenyTSConnections -Value 1 -Type DWord
        Set-ItemProperty -Path $nlaKey -Name UserAuthentication -Value 1 -Type DWord
        Disable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Log "RDP" "Connections + NLA" "Reverted to Windows default (RDP disabled, NLA required if re-enabled)"
    }
    elseif ($KeepRdp) {
        Set-ItemProperty -Path $rdpKey -Name fDenyTSConnections -Value 0 -Type DWord
        Set-ItemProperty -Path $nlaKey -Name UserAuthentication -Value 1 -Type DWord
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Log "RDP" "Kept enabled, Network Level Authentication required" "Done"
    }
    else {
        Set-ItemProperty -Path $rdpKey -Name fDenyTSConnections -Value 1 -Type DWord
        Disable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Log "RDP" "Inbound RDP disabled" "Done"
    }
}
#endregion

#region SSH (OpenSSH Server optional feature)
if ($Ssh) {
    $sshdConfig = "$env:ProgramData\ssh\sshd_config"
    # Keeps the script's old name on purpose: it's how blocks written before the rename
    # to 05.Secure-Windows.ps1 are still found and replaced/removed.
    $sshMarkBegin = "# BEGIN Secure-Windows11.ps1 hardening - do not edit by hand"
    $sshMarkEnd = "# END Secure-Windows11.ps1 hardening"
    $sshdSvc = Get-Service -Name sshd -ErrorAction SilentlyContinue

    function Remove-SshHardeningBlock {
        if (-not (Test-Path $sshdConfig)) { return }
        $text = [IO.File]::ReadAllText($sshdConfig)
        $pattern = "(?s)" + [regex]::Escape($sshMarkBegin) + ".*?" + [regex]::Escape($sshMarkEnd) + "\r?\n?"
        [IO.File]::WriteAllText($sshdConfig, [regex]::Replace($text, $pattern, ""))
    }

    function Test-AnyAuthorizedKeys {
        $candidates = @("$env:ProgramData\ssh\administrators_authorized_keys")
        $candidates += Get-ChildItem -Path "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName ".ssh\authorized_keys" }
        foreach ($f in $candidates) {
            if ((Test-Path $f) -and (Get-Item $f).Length -gt 0) { return $true }
        }
        return $false
    }

    if (-not $sshdSvc) {
        if ($mode -eq "Report") {
            $expected = if ($KeepSsh) { "Installed" } else { "Not installed" }
            Add-ReportRow "SSH" "OpenSSH Server" $expected "Not installed"
        } else {
            Log "SSH" "OpenSSH Server" "Not installed (Windows default) - nothing to do"
        }
    }
    elseif ($mode -eq "Report") {
        $expectedStart = if ($KeepSsh) { "Automatic" } else { "Disabled" }
        Add-ReportRow "SSH" "sshd startup type" $expectedStart $sshdSvc.StartType
        if ($KeepSsh) {
            $hasBlock = (Test-Path $sshdConfig) -and ([IO.File]::ReadAllText($sshdConfig).Contains($sshMarkBegin))
            Add-ReportRow "SSH" "Hardening block present" "True" $hasBlock
        }
    }
    elseif ($mode -eq "RestoreDefaults") {
        Remove-SshHardeningBlock
        Stop-Service -Name sshd -Force -ErrorAction SilentlyContinue
        Set-Service -Name sshd -StartupType Manual
        Log "SSH" "Hardening block removed, sshd" "Reverted to Windows default (Manual startup, stopped)"
    }
    elseif (-not $KeepSsh) {
        Stop-Service -Name sshd -Force -ErrorAction SilentlyContinue
        Set-Service -Name sshd -StartupType Disabled
        Disable-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
        Log "SSH" "OpenSSH Server disabled (service + firewall rule)" "Done"
    }
    else {
        $blockLines = @(
            $sshMarkBegin,
            "PermitEmptyPasswords no",
            "X11Forwarding no",
            "MaxAuthTries 4",
            "ClientAliveInterval 300",
            "ClientAliveCountMax 2"
        )
        if ($KeepPasswordAuth) {
            $blockLines += "PasswordAuthentication yes"
            $pwNote = "password auth kept enabled"
        } elseif (Test-AnyAuthorizedKeys) {
            $blockLines += "PasswordAuthentication no"
            $pwNote = "password auth disabled (key-based only)"
        } else {
            $blockLines += "# PasswordAuthentication left at its configured value - no authorized_keys file was found, so disabling it was skipped to avoid lockout."
            $pwNote = "password auth left enabled - no authorized_keys found for any user"
        }
        $blockLines += $sshMarkEnd

        # sshd keeps the FIRST value it reads for each keyword, and Windows' stock
        # sshd_config ends with a 'Match Group administrators' block - anything appended
        # after it would only apply inside that Match. So the block goes at the very top.
        Remove-SshHardeningBlock
        $existing = if (Test-Path $sshdConfig) { [IO.File]::ReadAllText($sshdConfig) } else { "" }
        [IO.File]::WriteAllText($sshdConfig, (($blockLines -join "`n") + "`n" + $existing))

        Set-Service -Name sshd -StartupType Automatic
        Restart-Service -Name sshd -Force -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
        Log "SSH" "OpenSSH Server kept enabled, hardened ($pwNote)" "Done"
    }
}
#endregion

#region Lockscreen / removable media
if ($Lockscreen) {
    $autorunKey    = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    $systemPolKey  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $winlogonKey   = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    # "Require a password when a computer wakes" (Group Policy > System > Power Management >
    # Sleep Settings) - the setting GUID under the Power policy key.
    $wakePwKey     = "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51"
    $idleSeconds   = 600

    # Older versions of this script set "Console lock display off timeout" (how long the
    # screen stays on AFTER it's already locked) believing it was the idle lock. Only
    # touched on restore now, to put it back to Windows' 60-second default.
    $consoleLockSubgroup = "7516b95f-f776-4464-8c53-06167f40cc99"
    $consoleLockSetting  = "8ec4b3a5-6868-48c2-be75-4f3044be88a7"

    $autoLogon = (Get-ItemProperty -Path $winlogonKey -Name AutoAdminLogon -ErrorAction SilentlyContinue).AutoAdminLogon

    if ($mode -eq "Report") {
        $idle = (Get-ItemProperty -Path $systemPolKey -Name InactivityTimeoutSecs -ErrorAction SilentlyContinue).InactivityTimeoutSecs
        Add-ReportRow "Lockscreen" "Machine inactivity lock (seconds)" "$idleSeconds" $(if ($null -eq $idle) { "Not configured (never)" } else { $idle })

        $wakeAc = (Get-ItemProperty -Path $wakePwKey -Name ACSettingIndex -ErrorAction SilentlyContinue).ACSettingIndex
        $wakeDc = (Get-ItemProperty -Path $wakePwKey -Name DCSettingIndex -ErrorAction SilentlyContinue).DCSettingIndex
        Add-ReportRow "Lockscreen" "Password on wake - AC (policy)" "1" $(if ($null -eq $wakeAc) { "Not configured (user choice)" } else { $wakeAc })
        Add-ReportRow "Lockscreen" "Password on wake - battery (policy)" "1" $(if ($null -eq $wakeDc) { "Not configured (user choice)" } else { $wakeDc })

        Add-ReportRow "Lockscreen" "Automatic sign-in (AutoAdminLogon)" "0" $(if ($null -eq $autoLogon) { "0" } else { $autoLogon })

        $autorun = Get-ItemProperty -Path $autorunKey -Name NoDriveTypeAutoRun -ErrorAction SilentlyContinue
        $foundAutorun = if ($null -eq $autorun) { "Not configured (default)" } else { $autorun.NoDriveTypeAutoRun }
        Add-ReportRow "Lockscreen" "Autorun/Autoplay (NoDriveTypeAutoRun)" "255" $foundAutorun
    }
    elseif ($mode -eq "RestoreDefaults") {
        Remove-ItemProperty -Path $systemPolKey -Name InactivityTimeoutSecs -ErrorAction SilentlyContinue
        Remove-Item -Path $wakePwKey -ErrorAction SilentlyContinue
        powercfg /setacvalueindex SCHEME_CURRENT $consoleLockSubgroup $consoleLockSetting 60 | Out-Null
        powercfg /setdcvalueindex SCHEME_CURRENT $consoleLockSubgroup $consoleLockSetting 60 | Out-Null
        powercfg /setactive SCHEME_CURRENT | Out-Null
        Log "Lockscreen" "Inactivity lock + password-on-wake policies" "Removed (not configured, Windows default)"
        Log "Lockscreen" "Automatic sign-in" "Left disabled - re-enabling passwordless sign-in isn't offered"

        if (Test-Path $autorunKey) {
            Remove-ItemProperty -Path $autorunKey -Name NoDriveTypeAutoRun -ErrorAction SilentlyContinue
        }
        Log "Lockscreen" "Autorun/Autoplay policy override" "Removed - Windows' own default now applies"
    }
    else {
        Set-ItemProperty -Path $systemPolKey -Name InactivityTimeoutSecs -Value $idleSeconds -Type DWord
        Log "Lockscreen" "Machine inactivity lock" "Set to 10 minutes"

        if (-not (Test-Path $wakePwKey)) { New-Item -Path $wakePwKey -Force | Out-Null }
        Set-ItemProperty -Path $wakePwKey -Name ACSettingIndex -Value 1 -Type DWord
        Set-ItemProperty -Path $wakePwKey -Name DCSettingIndex -Value 1 -Type DWord
        Log "Lockscreen" "Password on wake from sleep (AC + battery)" "Required"

        if ($autoLogon -eq "1") {
            Set-ItemProperty -Path $winlogonKey -Name AutoAdminLogon -Value "0" -Type String
            Remove-ItemProperty -Path $winlogonKey -Name DefaultPassword -ErrorAction SilentlyContinue
            Log "Lockscreen" "Automatic sign-in" "Disabled (stored DefaultPassword removed)"
        } else {
            Log "Lockscreen" "Automatic sign-in" "Already disabled"
        }

        if (-not (Test-Path $autorunKey)) { New-Item -Path $autorunKey -Force | Out-Null }
        Set-ItemProperty -Path $autorunKey -Name NoDriveTypeAutoRun -Value 255 -Type DWord
        Log "Lockscreen" "Autorun/Autoplay for all drive types" "Disabled"
    }
}
#endregion

#region Audit policy
if ($Audit) {
    $subcats = @(
        "Logon", "Logoff", "Account Lockout",
        "User Account Management", "Security Group Management",
        "Sensitive Privilege Use", "Credential Validation"
    )

    if ($mode -eq "Report") {
        foreach ($s in $subcats) {
            $csv = auditpol /get /subcategory:"$s" /r | ConvertFrom-Csv
            $found = if ($csv) { $csv[0].'Inclusion Setting' } else { "Unknown" }
            Add-ReportRow "Audit" "$s" "Success and Failure" $found
        }
    }
    elseif ($mode -eq "RestoreDefaults") {
        foreach ($s in $subcats) {
            auditpol /set /subcategory:"$s" /success:disable /failure:disable | Out-Null
        }
        Log "Audit" "Local audit policy" "Reverted to Windows default (explicit auditing turned off)"
    }
    else {
        foreach ($s in $subcats) {
            auditpol /set /subcategory:"$s" /success:enable /failure:enable | Out-Null
        }
        Log "Audit" "Local audit policy (logon, account mgmt, privilege use)" "Enabled success+failure"
    }
}
#endregion

#region Credential & authentication hardening
if ($CredentialHardening) {
    $lsaKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    $wshKey = "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings"

    # "Password must meet complexity requirements" has no registry or 'net accounts'
    # equivalent - it's only reachable through the local security policy database.
    function Get-PasswordComplexity {
        $inf = Join-Path $env:TEMP "secpol-$PID.inf"
        secedit /export /cfg $inf /areas SECURITYPOLICY | Out-Null
        $line = Get-Content $inf -ErrorAction SilentlyContinue | Where-Object { $_ -match '^PasswordComplexity\s*=' }
        Remove-Item $inf -ErrorAction SilentlyContinue
        if ($line) { ($line -split '=')[1].Trim() } else { "Unknown" }
    }
    function Set-PasswordComplexity([int]$Value) {
        $inf = Join-Path $env:TEMP "secpol-$PID.inf"
        $db  = Join-Path $env:TEMP "secpol-$PID.sdb"
        secedit /export /cfg $inf /areas SECURITYPOLICY | Out-Null
        (Get-Content $inf) -replace '^PasswordComplexity\s*=.*', "PasswordComplexity = $Value" | Set-Content $inf -Encoding Unicode
        secedit /configure /db $db /cfg $inf /areas SECURITYPOLICY | Out-Null
        Remove-Item $inf, "$db*" -ErrorAction SilentlyContinue
    }

    if ($mode -eq "Report") {
        $lmVal = (Get-ItemProperty -Path $lsaKey -Name LmCompatibilityLevel -ErrorAction SilentlyContinue).LmCompatibilityLevel
        Add-ReportRow "CredentialHardening" "NTLM compatibility level (5 = NTLMv2 only)" "5" $(if ($null -eq $lmVal) {"Not configured (default ~3)"} else {$lmVal})

        $raSam = (Get-ItemProperty -Path $lsaKey -Name RestrictAnonymousSAM -ErrorAction SilentlyContinue).RestrictAnonymousSAM
        Add-ReportRow "CredentialHardening" "Restrict anonymous SAM enumeration" "1" $(if ($null -eq $raSam) {"Not configured (default 1)"} else {$raSam})

        $ra = (Get-ItemProperty -Path $lsaKey -Name RestrictAnonymous -ErrorAction SilentlyContinue).RestrictAnonymous
        Add-ReportRow "CredentialHardening" "Restrict anonymous enumeration of SAM accounts and shares" "1" $(if ($null -eq $ra) {"Not configured (default 0)"} else {$ra})

        $wsh = (Get-ItemProperty -Path $wshKey -Name Enabled -ErrorAction SilentlyContinue).Enabled
        Add-ReportRow "CredentialHardening" "Windows Script Host enabled" "0" $(if ($null -eq $wsh) {"Not configured (default 1/enabled)"} else {$wsh})

        $guest = Get-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
        Add-ReportRow "CredentialHardening" "Guest account enabled" "False" $(if ($guest) {$guest.Enabled} else {"Not found"})

        $naOut = (net accounts) -join "`n"
        $minLen = if ($naOut -match "Minimum password length:\s*(\S+)") { $Matches[1] } else { "Unknown" }
        $lockThresh = if ($naOut -match "Lockout threshold:\s*(\S+)") { $Matches[1] } else { "Unknown" }
        Add-ReportRow "CredentialHardening" "Minimum password length" "14" $minLen
        Add-ReportRow "CredentialHardening" "Password complexity required (3 of 4 character types)" "1" (Get-PasswordComplexity)
        $lockDur = if ($naOut -match "Lockout duration \(minutes\):\s*(\S+)") { $Matches[1] } else { "Unknown" }
        Add-ReportRow "CredentialHardening" "Lockout duration (minutes)" "15" $lockDur
        Add-ReportRow "CredentialHardening" "Lockout threshold (bad attempts)" "10" $lockThresh
    }
    elseif ($mode -eq "RestoreDefaults") {
        Remove-ItemProperty -Path $lsaKey -Name LmCompatibilityLevel -ErrorAction SilentlyContinue
        Log "CredentialHardening" "NTLM compatibility level" "Reverted to Windows default (not configured)"

        Set-ItemProperty -Path $lsaKey -Name RestrictAnonymousSAM -Value 1 -Type DWord
        Set-ItemProperty -Path $lsaKey -Name RestrictAnonymous -Value 0 -Type DWord
        Log "CredentialHardening" "Anonymous enumeration restrictions" "Reverted to Windows defaults"

        if (Test-Path $wshKey) { Remove-ItemProperty -Path $wshKey -Name Enabled -ErrorAction SilentlyContinue }
        Log "CredentialHardening" "Windows Script Host" "Reverted to Windows default (enabled)"

        Log "CredentialHardening" "Guest account" "Left disabled - that is the Windows default"

        net accounts /minpwlen:0 /lockoutthreshold:0 /lockoutduration:30 /lockoutwindow:30 | Out-Null
        Set-PasswordComplexity 0
        Log "CredentialHardening" "Password/lockout policy" "Reverted to Windows defaults (no minimum length, no complexity, no lockout)"
    }
    else {
        if (-not (Test-Path $lsaKey)) { New-Item -Path $lsaKey -Force | Out-Null }
        Set-ItemProperty -Path $lsaKey -Name LmCompatibilityLevel -Value 5 -Type DWord
        Log "CredentialHardening" "NTLM compatibility level" "Set to 5 (NTLMv2 only, refuse LM/NTLMv1)"

        Set-ItemProperty -Path $lsaKey -Name RestrictAnonymousSAM -Value 1 -Type DWord
        Set-ItemProperty -Path $lsaKey -Name RestrictAnonymous -Value 1 -Type DWord
        Log "CredentialHardening" "Anonymous SAM/share enumeration" "Restricted"

        if (-not (Test-Path $wshKey)) { New-Item -Path $wshKey -Force | Out-Null }
        Set-ItemProperty -Path $wshKey -Name Enabled -Value 0 -Type DWord
        Log "CredentialHardening" "Windows Script Host" "Disabled (blocks .vbs/.js execution via wscript/cscript)"

        $guest = Get-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
        if ($guest -and $guest.Enabled) {
            Disable-LocalUser -Name "Guest"
            Log "CredentialHardening" "Guest account" "Disabled"
        } else {
            Log "CredentialHardening" "Guest account" "Already disabled"
        }

        net accounts /minpwlen:14 /lockoutthreshold:10 /lockoutduration:15 /lockoutwindow:15 | Out-Null
        Set-PasswordComplexity 1
        Log "CredentialHardening" "Password/lockout policy" "Minimum length 14, complexity required, 15-minute lockout after 10 bad attempts (checked at next password change)"
    }
}
#endregion

#region Attack surface extras
if ($AttackSurfaceExtras) {
    $psLogKey  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    $psModKey  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging"
    $psTransKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"
    $mdnsKey   = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    $raKey     = "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance"
    $psv2Feature = "MicrosoftWindowsPowerShellV2Root"
    $transcriptDir = "C:\ProgramData\PSTranscripts"

    if ($mode -eq "Report") {
        $netProt = (Get-MpPreference).EnableNetworkProtection
        $netProtMap = @{0="Disabled"; 1="Enabled"; 2="AuditMode"}
        Add-ReportRow "AttackSurfaceExtras" "Defender Network Protection" "Enabled" $netProtMap[[int]$netProt]

        $psv2 = Get-WindowsOptionalFeature -Online -FeatureName $psv2Feature -ErrorAction SilentlyContinue
        if ($psv2) {
            Add-ReportRow "AttackSurfaceExtras" "PowerShell 2.0 engine" "Disabled" $psv2.State
        } else {
            # Many current Windows 11 images have dropped this optional feature from the
            # OS package set entirely - that satisfies the hardening goal (no v2 engine
            # present) just as much as an explicit Disabled state does, so it's reported
            # as a match rather than Unknown.
            Add-ReportRow "AttackSurfaceExtras" "PowerShell 2.0 engine" "Disabled" "Disabled"
            Write-Host "[AttackSurfaceExtras] Note: PowerShell 2.0 engine feature isn't present in this OS image at all (nothing to disable)." -ForegroundColor DarkGray
        }

        $sbl = (Get-ItemProperty -Path $psLogKey -Name EnableScriptBlockLogging -ErrorAction SilentlyContinue).EnableScriptBlockLogging
        Add-ReportRow "AttackSurfaceExtras" "PowerShell script block logging" "1" $(if ($null -eq $sbl) {"Not configured (default off)"} else {$sbl})

        $modLog = (Get-ItemProperty -Path $psModKey -Name EnableModuleLogging -ErrorAction SilentlyContinue).EnableModuleLogging
        Add-ReportRow "AttackSurfaceExtras" "PowerShell module logging" "1" $(if ($null -eq $modLog) {"Not configured (default off)"} else {$modLog})

        $trans = (Get-ItemProperty -Path $psTransKey -Name EnableTranscripting -ErrorAction SilentlyContinue).EnableTranscripting
        Add-ReportRow "AttackSurfaceExtras" "PowerShell transcription" "1" $(if ($null -eq $trans) {"Not configured (default off)"} else {$trans})

        $mdns = (Get-ItemProperty -Path $mdnsKey -Name EnableMDNS -ErrorAction SilentlyContinue).EnableMDNS
        Add-ReportRow "AttackSurfaceExtras" "mDNS enabled" "0" $(if ($null -eq $mdns) {"Not configured (default 1/enabled)"} else {$mdns})

        $raHelp = (Get-ItemProperty -Path $raKey -Name fAllowToGetHelp -ErrorAction SilentlyContinue).fAllowToGetHelp
        Add-ReportRow "AttackSurfaceExtras" "Remote Assistance allowed" "0" $(if ($null -eq $raHelp) {"Not configured (default 1/enabled)"} else {$raHelp})
    }
    elseif ($mode -eq "RestoreDefaults") {
        Set-MpPreference -EnableNetworkProtection Disabled
        Log "AttackSurfaceExtras" "Defender Network Protection" "Reverted to Windows default (disabled)"

        $psv2 = Get-WindowsOptionalFeature -Online -FeatureName $psv2Feature -ErrorAction SilentlyContinue
        if ($psv2 -and $psv2.State -eq 'Disabled') {
            Enable-WindowsOptionalFeature -Online -FeatureName $psv2Feature -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Log "AttackSurfaceExtras" "PowerShell 2.0 engine" "Reinstalled (Windows default state)"
        } else {
            Log "AttackSurfaceExtras" "PowerShell 2.0 engine" "Already present / not disabled"
        }

        Remove-Item -Path $psLogKey -ErrorAction SilentlyContinue
        Remove-Item -Path $psModKey -ErrorAction SilentlyContinue
        Remove-Item -Path $psTransKey -ErrorAction SilentlyContinue
        Log "AttackSurfaceExtras" "PowerShell logging policies" "Removed (unconfigured, Windows default)"

        if (Test-Path $mdnsKey) { Remove-ItemProperty -Path $mdnsKey -Name EnableMDNS -ErrorAction SilentlyContinue }
        Log "AttackSurfaceExtras" "mDNS" "Reverted to Windows default (enabled)"

        Set-ItemProperty -Path $raKey -Name fAllowToGetHelp -Value 1 -Type DWord
        Log "AttackSurfaceExtras" "Remote Assistance" "Reverted to Windows default (enabled)"
    }
    else {
        Set-MpPreference -EnableNetworkProtection Enabled
        Log "AttackSurfaceExtras" "Defender Network Protection" "Enabled"

        $psv2 = Get-WindowsOptionalFeature -Online -FeatureName $psv2Feature -ErrorAction SilentlyContinue
        if ($psv2 -and $psv2.State -eq 'Enabled') {
            Disable-WindowsOptionalFeature -Online -FeatureName $psv2Feature -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Log "AttackSurfaceExtras" "PowerShell 2.0 engine" "Removed"
        } else {
            Log "AttackSurfaceExtras" "PowerShell 2.0 engine" "Already absent"
        }

        if (-not (Test-Path $psLogKey)) { New-Item -Path $psLogKey -Force | Out-Null }
        Set-ItemProperty -Path $psLogKey -Name EnableScriptBlockLogging -Value 1 -Type DWord

        if (-not (Test-Path $psModKey)) { New-Item -Path $psModKey -Force | Out-Null }
        Set-ItemProperty -Path $psModKey -Name EnableModuleLogging -Value 1 -Type DWord
        $psModNamesKey = "$psModKey\ModuleNames"
        if (-not (Test-Path $psModNamesKey)) { New-Item -Path $psModNamesKey -Force | Out-Null }
        Set-ItemProperty -Path $psModNamesKey -Name "*" -Value "*" -Type String

        if (-not (Test-Path $psTransKey)) { New-Item -Path $psTransKey -Force | Out-Null }
        Set-ItemProperty -Path $psTransKey -Name EnableTranscripting -Value 1 -Type DWord
        Set-ItemProperty -Path $psTransKey -Name EnableInvocationHeader -Value 1 -Type DWord
        Set-ItemProperty -Path $psTransKey -Name OutputDirectory -Value $transcriptDir -Type String
        if (-not (Test-Path $transcriptDir)) { New-Item -Path $transcriptDir -ItemType Directory -Force | Out-Null }
        Log "AttackSurfaceExtras" "PowerShell script block/module logging + transcription" "Enabled, transcripts to $transcriptDir"

        if (-not (Test-Path $mdnsKey)) { New-Item -Path $mdnsKey -Force | Out-Null }
        Set-ItemProperty -Path $mdnsKey -Name EnableMDNS -Value 0 -Type DWord
        Log "AttackSurfaceExtras" "mDNS" "Disabled"

        Set-ItemProperty -Path $raKey -Name fAllowToGetHelp -Value 0 -Type DWord
        Log "AttackSurfaceExtras" "Remote Assistance" "Disabled"
    }
}
#endregion

#region Privacy
if ($Privacy) {
    $telemetryKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    $adInfoKey    = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"
    $cloudKey     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    $activityKey  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    $recallKey    = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
    $searchKey    = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    $inkingKey    = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC"
    $copilotKey   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    $explorerPolKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"

    if ($mode -eq "Report") {
        $telemetry = (Get-ItemProperty -Path $telemetryKey -Name AllowTelemetry -ErrorAction SilentlyContinue).AllowTelemetry
        Add-ReportRow "Privacy" "Diagnostic data level (1 = Required/Basic)" "1" $(if ($null -eq $telemetry) {"Not configured (default 3/Full)"} else {$telemetry})

        $adId = (Get-ItemProperty -Path $adInfoKey -Name DisabledByGroupPolicy -ErrorAction SilentlyContinue).DisabledByGroupPolicy
        Add-ReportRow "Privacy" "Advertising ID disabled (policy)" "1" $(if ($null -eq $adId) {"Not configured (default 0/enabled)"} else {$adId})

        $tailored = (Get-ItemProperty -Path $cloudKey -Name DisableTailoredExperiencesWithDiagnosticData -ErrorAction SilentlyContinue).DisableTailoredExperiencesWithDiagnosticData
        Add-ReportRow "Privacy" "Tailored experiences disabled" "1" $(if ($null -eq $tailored) {"Not configured (default 0/enabled)"} else {$tailored})

        $consumerFeatures = (Get-ItemProperty -Path $cloudKey -Name DisableWindowsConsumerFeatures -ErrorAction SilentlyContinue).DisableWindowsConsumerFeatures
        Add-ReportRow "Privacy" "Consumer features (Store promos, suggested apps) disabled" "1" $(if ($null -eq $consumerFeatures) {"Not configured (default 0/enabled)"} else {$consumerFeatures})

        $thirdPartySugg = (Get-ItemProperty -Path $cloudKey -Name DisableThirdPartySuggestions -ErrorAction SilentlyContinue).DisableThirdPartySuggestions
        Add-ReportRow "Privacy" "Start menu third-party suggestions disabled" "1" $(if ($null -eq $thirdPartySugg) {"Not configured (default 0/enabled)"} else {$thirdPartySugg})

        $feed = (Get-ItemProperty -Path $activityKey -Name EnableActivityFeed -ErrorAction SilentlyContinue).EnableActivityFeed
        $pub  = (Get-ItemProperty -Path $activityKey -Name PublishUserActivities -ErrorAction SilentlyContinue).PublishUserActivities
        $up   = (Get-ItemProperty -Path $activityKey -Name UploadUserActivities -ErrorAction SilentlyContinue).UploadUserActivities
        Add-ReportRow "Privacy" "Activity feed enabled" "0" $(if ($null -eq $feed) {"Not configured (default 1/enabled)"} else {$feed})
        Add-ReportRow "Privacy" "Publish user activities" "0" $(if ($null -eq $pub) {"Not configured (default 1/enabled)"} else {$pub})
        Add-ReportRow "Privacy" "Upload user activities" "0" $(if ($null -eq $up) {"Not configured (default 1/enabled)"} else {$up})

        $recallData = (Get-ItemProperty -Path $recallKey -Name DisableAIDataAnalysis -ErrorAction SilentlyContinue).DisableAIDataAnalysis
        Add-ReportRow "Privacy" "Recall snapshot saving disabled" "1" $(if ($null -eq $recallData) {"Not configured (default 0/enabled where supported)"} else {$recallData})

        $recallAllow = (Get-ItemProperty -Path $recallKey -Name AllowRecallEnablement -ErrorAction SilentlyContinue).AllowRecallEnablement
        Add-ReportRow "Privacy" "Recall feature allowed" "0" $(if ($null -eq $recallAllow) {"Not configured (default 1/allowed where supported)"} else {$recallAllow})

        $webSearch = (Get-ItemProperty -Path $searchKey -Name DisableWebSearch -ErrorAction SilentlyContinue).DisableWebSearch
        Add-ReportRow "Privacy" "Start menu web search disabled" "1" $(if ($null -eq $webSearch) {"Not configured (default 0/enabled)"} else {$webSearch})

        $cortana = (Get-ItemProperty -Path $searchKey -Name AllowCortana -ErrorAction SilentlyContinue).AllowCortana
        Add-ReportRow "Privacy" "Cortana allowed" "0" $(if ($null -eq $cortana) {"Not configured (default 1/allowed)"} else {$cortana})

        $inking = (Get-ItemProperty -Path $inkingKey -Name AllowInputPersonalization -ErrorAction SilentlyContinue).AllowInputPersonalization
        Add-ReportRow "Privacy" "Inking/typing personalization allowed" "0" $(if ($null -eq $inking) {"Not configured (default 1/allowed)"} else {$inking})

        $copilot = (Get-ItemProperty -Path $copilotKey -Name TurnOffWindowsCopilot -ErrorAction SilentlyContinue).TurnOffWindowsCopilot
        Add-ReportRow "Privacy" "Windows Copilot turned off" "1" $(if ($null -eq $copilot) {"Not configured (default 0/enabled)"} else {$copilot})

        $recentDocs = (Get-ItemProperty -Path $explorerPolKey -Name NoRecentDocsHistory -ErrorAction SilentlyContinue).NoRecentDocsHistory
        Add-ReportRow "Privacy" "Recent documents history disabled" "1" $(if ($null -eq $recentDocs) {"Not configured (default 0/enabled)"} else {$recentDocs})
    }
    elseif ($mode -eq "RestoreDefaults") {
        if (Test-Path $telemetryKey) { Remove-ItemProperty -Path $telemetryKey -Name AllowTelemetry -ErrorAction SilentlyContinue }
        if (Test-Path $adInfoKey) { Remove-ItemProperty -Path $adInfoKey -Name DisabledByGroupPolicy -ErrorAction SilentlyContinue }
        if (Test-Path $cloudKey) {
            Remove-ItemProperty -Path $cloudKey -Name DisableTailoredExperiencesWithDiagnosticData -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $cloudKey -Name DisableWindowsConsumerFeatures -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $cloudKey -Name DisableThirdPartySuggestions -ErrorAction SilentlyContinue
        }
        if (Test-Path $activityKey) {
            Remove-ItemProperty -Path $activityKey -Name EnableActivityFeed -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $activityKey -Name PublishUserActivities -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $activityKey -Name UploadUserActivities -ErrorAction SilentlyContinue
        }
        if (Test-Path $recallKey) {
            Remove-ItemProperty -Path $recallKey -Name DisableAIDataAnalysis -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $recallKey -Name AllowRecallEnablement -ErrorAction SilentlyContinue
        }
        if (Test-Path $searchKey) {
            Remove-ItemProperty -Path $searchKey -Name DisableWebSearch -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $searchKey -Name AllowCortana -ErrorAction SilentlyContinue
        }
        if (Test-Path $inkingKey) { Remove-ItemProperty -Path $inkingKey -Name AllowInputPersonalization -ErrorAction SilentlyContinue }
        if (Test-Path $copilotKey) { Remove-ItemProperty -Path $copilotKey -Name TurnOffWindowsCopilot -ErrorAction SilentlyContinue }
        if (Test-Path $explorerPolKey) { Remove-ItemProperty -Path $explorerPolKey -Name NoRecentDocsHistory -ErrorAction SilentlyContinue }

        Log "Privacy" "Telemetry/ads/Recall/search/Cortana/inking/Copilot/recent-docs policies" "Removed (unconfigured, Windows default applies)"
    }
    else {
        if (-not (Test-Path $telemetryKey)) { New-Item -Path $telemetryKey -Force | Out-Null }
        Set-ItemProperty -Path $telemetryKey -Name AllowTelemetry -Value 1 -Type DWord
        Log "Privacy" "Diagnostic data level" "Lowered to Required/Basic"

        if (-not (Test-Path $adInfoKey)) { New-Item -Path $adInfoKey -Force | Out-Null }
        Set-ItemProperty -Path $adInfoKey -Name DisabledByGroupPolicy -Value 1 -Type DWord
        Log "Privacy" "Advertising ID" "Disabled machine-wide"

        if (-not (Test-Path $cloudKey)) { New-Item -Path $cloudKey -Force | Out-Null }
        Set-ItemProperty -Path $cloudKey -Name DisableTailoredExperiencesWithDiagnosticData -Value 1 -Type DWord
        Set-ItemProperty -Path $cloudKey -Name DisableWindowsConsumerFeatures -Value 1 -Type DWord
        Set-ItemProperty -Path $cloudKey -Name DisableThirdPartySuggestions -Value 1 -Type DWord
        Log "Privacy" "Tailored experiences, consumer features, Start menu suggestions" "Disabled"

        if (-not (Test-Path $activityKey)) { New-Item -Path $activityKey -Force | Out-Null }
        Set-ItemProperty -Path $activityKey -Name EnableActivityFeed -Value 0 -Type DWord
        Set-ItemProperty -Path $activityKey -Name PublishUserActivities -Value 0 -Type DWord
        Set-ItemProperty -Path $activityKey -Name UploadUserActivities -Value 0 -Type DWord
        Log "Privacy" "Activity history (feed/publish/upload)" "Disabled"

        if (-not (Test-Path $recallKey)) { New-Item -Path $recallKey -Force | Out-Null }
        Set-ItemProperty -Path $recallKey -Name DisableAIDataAnalysis -Value 1 -Type DWord
        Set-ItemProperty -Path $recallKey -Name AllowRecallEnablement -Value 0 -Type DWord
        Log "Privacy" "Windows Recall" "Disabled (snapshot saving blocked, feature not allowed)"

        if (-not (Test-Path $searchKey)) { New-Item -Path $searchKey -Force | Out-Null }
        Set-ItemProperty -Path $searchKey -Name DisableWebSearch -Value 1 -Type DWord
        Set-ItemProperty -Path $searchKey -Name AllowCortana -Value 0 -Type DWord
        Log "Privacy" "Start menu web search + Cortana" "Disabled"

        if (-not (Test-Path $inkingKey)) { New-Item -Path $inkingKey -Force | Out-Null }
        Set-ItemProperty -Path $inkingKey -Name AllowInputPersonalization -Value 0 -Type DWord
        Log "Privacy" "Inking/typing personalization" "Disabled"

        if (-not (Test-Path $copilotKey)) { New-Item -Path $copilotKey -Force | Out-Null }
        Set-ItemProperty -Path $copilotKey -Name TurnOffWindowsCopilot -Value 1 -Type DWord
        Log "Privacy" "Windows Copilot" "Turned off"

        if (-not (Test-Path $explorerPolKey)) { New-Item -Path $explorerPolKey -Force | Out-Null }
        Set-ItemProperty -Path $explorerPolKey -Name NoRecentDocsHistory -Value 1 -Type DWord
        Log "Privacy" "Recent documents history" "Disabled"
    }
}
#endregion

#region Privacy - strict (location, camera/mic app access, cross-device clipboard)
# Opt-in only - NOT included in -All, since disabling camera/mic app access can silently
# break video calls (Teams, Zoom, etc.) until you carve out per-app exceptions.
if ($PrivacyStrict) {
    $locationKey  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
    $appPrivKey   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
    $clipboardKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"

    if ($mode -eq "Report") {
        $loc = (Get-ItemProperty -Path $locationKey -Name DisableLocation -ErrorAction SilentlyContinue).DisableLocation
        Add-ReportRow "PrivacyStrict" "Location services disabled (machine-wide)" "1" $(if ($null -eq $loc) {"Not configured (default 0/enabled)"} else {$loc})

        $cam = (Get-ItemProperty -Path $appPrivKey -Name LetAppsAccessCamera -ErrorAction SilentlyContinue).LetAppsAccessCamera
        Add-ReportRow "PrivacyStrict" "App camera access (2 = force deny)" "2" $(if ($null -eq $cam) {"Not configured (default 0/user choice)"} else {$cam})

        $mic = (Get-ItemProperty -Path $appPrivKey -Name LetAppsAccessMicrophone -ErrorAction SilentlyContinue).LetAppsAccessMicrophone
        Add-ReportRow "PrivacyStrict" "App microphone access (2 = force deny)" "2" $(if ($null -eq $mic) {"Not configured (default 0/user choice)"} else {$mic})

        $clip = (Get-ItemProperty -Path $clipboardKey -Name AllowCrossDeviceClipboard -ErrorAction SilentlyContinue).AllowCrossDeviceClipboard
        Add-ReportRow "PrivacyStrict" "Cross-device clipboard sync allowed" "0" $(if ($null -eq $clip) {"Not configured (default 1/allowed)"} else {$clip})
    }
    elseif ($mode -eq "RestoreDefaults") {
        if (Test-Path $locationKey) { Remove-ItemProperty -Path $locationKey -Name DisableLocation -ErrorAction SilentlyContinue }
        if (Test-Path $appPrivKey) {
            Remove-ItemProperty -Path $appPrivKey -Name LetAppsAccessCamera -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $appPrivKey -Name LetAppsAccessMicrophone -ErrorAction SilentlyContinue
        }
        if (Test-Path $clipboardKey) { Remove-ItemProperty -Path $clipboardKey -Name AllowCrossDeviceClipboard -ErrorAction SilentlyContinue }
        Log "PrivacyStrict" "Location/camera/microphone/clipboard policies" "Removed (unconfigured, Windows default applies - camera/mic back to user's own per-app choice)"
    }
    else {
        if (-not (Test-Path $locationKey)) { New-Item -Path $locationKey -Force | Out-Null }
        Set-ItemProperty -Path $locationKey -Name DisableLocation -Value 1 -Type DWord
        Log "PrivacyStrict" "Location services" "Disabled machine-wide"

        if (-not (Test-Path $appPrivKey)) { New-Item -Path $appPrivKey -Force | Out-Null }
        Set-ItemProperty -Path $appPrivKey -Name LetAppsAccessCamera -Value 2 -Type DWord
        Set-ItemProperty -Path $appPrivKey -Name LetAppsAccessMicrophone -Value 2 -Type DWord
        Log "PrivacyStrict" "App camera/microphone access" "Force-denied for all apps - THIS WILL BREAK Teams/Zoom/etc. until reverted or app-specific exceptions are set"

        if (-not (Test-Path $clipboardKey)) { New-Item -Path $clipboardKey -Force | Out-Null }
        Set-ItemProperty -Path $clipboardKey -Name AllowCrossDeviceClipboard -Value 0 -Type DWord
        Log "PrivacyStrict" "Cross-device clipboard sync" "Disabled"
    }
}
#endregion

#region Microsoft Edge
if ($Edge) {
    $edgeKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

    # Data-driven: each entry is a simple DWord policy under $edgeKey. Same policy set as
    # 05.Secure-Mac.py's --edge / --edge-strict - keep them in sync.
    $edgeSettings = @(
        @{ Name = "SmartScreenEnabled";                    Label = "SmartScreen (malicious site blocking)";        Harden = 1; DefaultText = "Not configured (default enabled)" }
        @{ Name = "SmartScreenPuaEnabled";                 Label = "SmartScreen PUA blocking";                     Harden = 1; DefaultText = "Not configured (default enabled)" }
        @{ Name = "SmartScreenForTrustedDownloadsEnabled"; Label = "SmartScreen for trusted-domain downloads";     Harden = 1; DefaultText = "Not configured (default enabled)" }
        @{ Name = "BlockThirdPartyCookies";                Label = "Block third-party cookies";                    Harden = 1; DefaultText = "Not configured (default 0/allowed)" }
        @{ Name = "TrackingPrevention";                    Label = "Tracking prevention (2=Balanced, 3=Strict)";   Harden = 2; DefaultText = "Not configured (user choice, default Balanced)" }
        @{ Name = "PasswordLeakDetectionEnabled";          Label = "Password leak detection";                      Harden = 1; DefaultText = "Not configured (default enabled)" }
        @{ Name = "AutofillCreditCardEnabled";             Label = "Credit card autofill/storage";                 Harden = 0; DefaultText = "Not configured (default enabled)" }
        @{ Name = "NetworkPredictionOptions";              Label = "Network prediction/prefetch (2=disabled)";     Harden = 2; DefaultText = "Not configured (default 0/enabled)" }
        @{ Name = "AlternateErrorPagesEnabled";            Label = "Alternate error pages (sends failed URLs out)"; Harden = 0; DefaultText = "Not configured (default enabled)" }
        @{ Name = "EdgeShoppingAssistantEnabled";          Label = "Shopping assistant";                           Harden = 0; DefaultText = "Not configured (default enabled)" }
        @{ Name = "PersonalizationReportingEnabled";       Label = "Personalization reporting";                    Harden = 0; DefaultText = "Not configured (default enabled)" }
        @{ Name = "UserFeedbackAllowed";                   Label = "User feedback prompts";                        Harden = 0; DefaultText = "Not configured (default enabled)" }
        @{ Name = "ConfigureDoNotTrack";                   Label = "Send Do Not Track header";                     Harden = 1; DefaultText = "Not configured (default off)" }
        @{ Name = "MetricsReportingEnabled";               Label = "Diagnostic/usage metrics reporting";           Harden = 0; DefaultText = "Not configured (default enabled)" }
        @{ Name = "EnhanceSecurityMode";                   Label = "Enhance security on the web (1=Balanced, 2=Strict)"; Harden = 1; DefaultText = "Not configured (default 0/off)" }
        @{ Name = "StartupBoostEnabled";                   Label = "Startup boost (background prelaunch process)"; Harden = 0; DefaultText = "Not configured (default enabled)" }
    )

    if ($mode -eq "Report") {
        foreach ($s in $edgeSettings) {
            $val = (Get-ItemProperty -Path $edgeKey -Name $s.Name -ErrorAction SilentlyContinue).($s.Name)
            Add-ReportRow "Edge" $s.Label $s.Harden $(if ($null -eq $val) { $s.DefaultText } else { $val })
        }
    }
    elseif ($mode -eq "RestoreDefaults") {
        if (Test-Path $edgeKey) {
            foreach ($s in $edgeSettings) { Remove-ItemProperty -Path $edgeKey -Name $s.Name -ErrorAction SilentlyContinue }
        }
        Log "Edge" "$($edgeSettings.Count) browser policies" "Removed (unconfigured, Windows/Edge defaults apply)"
    }
    else {
        if (-not (Test-Path $edgeKey)) { New-Item -Path $edgeKey -Force | Out-Null }
        foreach ($s in $edgeSettings) { Set-ItemProperty -Path $edgeKey -Name $s.Name -Value $s.Harden -Type DWord }
        Log "Edge" "$($edgeSettings.Count) browser privacy/security policies" "Applied (SmartScreen, tracking prevention, cookie blocking, telemetry off, etc.)"
    }
}
#endregion

#region Microsoft Edge - strict (HTTPS-only, no cert bypass, sync/password manager off)
# Opt-in only - NOT included in -All. HttpsOnlyMode will break plain-HTTP intranet/homelab
# pages (including your own PKI CDP/AIA base URL at http://pki.nativehome.net/pki/ if you
# ever browse it), and SSLErrorOverrideAllowed=0 will block clicking through self-signed
# cert warnings for internal sites unless your Nativehome-Root-CA-5 is fully trusted on
# this machine. Review both before enabling on a box that touches your homelab.
if ($EdgeStrict) {
    $edgeKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

    $edgeStrictSettings = @(
        @{ Name = "TrackingPrevention";       Label = "Tracking prevention (escalated to 3=Strict)";   Harden = 3; DefaultText = "Not configured (user choice, default Balanced)" }
        @{ Name = "EnhanceSecurityMode";      Label = "Enhance security on the web (escalated to 2=Strict)"; Harden = 2; DefaultText = "Not configured (default 0/off)" }
        @{ Name = "BrowserSignin";            Label = "Browser sign-in (0 = disabled)";                  Harden = 0; DefaultText = "Not configured (default 1/enabled)" }
        @{ Name = "SyncDisabled";             Label = "Edge account sync";                              Harden = 1; DefaultText = "Not configured (default 0/enabled)" }
        @{ Name = "PasswordManagerEnabled";   Label = "Built-in password manager";                       Harden = 0; DefaultText = "Not configured (default enabled)" }
        @{ Name = "SearchSuggestEnabled";     Label = "Search suggestions while typing";                 Harden = 0; DefaultText = "Not configured (default enabled)" }
        @{ Name = "SSLErrorOverrideAllowed";  Label = "Allow bypassing SSL certificate warnings";        Harden = 0; DefaultText = "Not configured (default allowed)" }
    )

    if ($mode -eq "Report") {
        foreach ($s in $edgeStrictSettings) {
            $val = (Get-ItemProperty -Path $edgeKey -Name $s.Name -ErrorAction SilentlyContinue).($s.Name)
            Add-ReportRow "EdgeStrict" $s.Label $s.Harden $(if ($null -eq $val) { $s.DefaultText } else { $val })
        }
        $httpsOnly = (Get-ItemProperty -Path $edgeKey -Name "HttpsOnlyMode" -ErrorAction SilentlyContinue).HttpsOnlyMode
        Add-ReportRow "EdgeStrict" "HTTPS-Only mode" "force_enabled" $(if ($null -eq $httpsOnly) { "Not configured (default allowed)" } else { $httpsOnly })
    }
    elseif ($mode -eq "RestoreDefaults") {
        if (Test-Path $edgeKey) {
            foreach ($s in $edgeStrictSettings) { Remove-ItemProperty -Path $edgeKey -Name $s.Name -ErrorAction SilentlyContinue }
            Remove-ItemProperty -Path $edgeKey -Name "HttpsOnlyMode" -ErrorAction SilentlyContinue
        }
        Log "EdgeStrict" "Strict browser policies" "Removed (unconfigured, Windows/Edge defaults apply)"
    }
    else {
        if (-not (Test-Path $edgeKey)) { New-Item -Path $edgeKey -Force | Out-Null }
        foreach ($s in $edgeStrictSettings) { Set-ItemProperty -Path $edgeKey -Name $s.Name -Value $s.Harden -Type DWord }
        Set-ItemProperty -Path $edgeKey -Name "HttpsOnlyMode" -Value "force_enabled" -Type String
        Log "EdgeStrict" "Strict browser policies" "Applied - HTTPS-only enforced, cert-warning bypass blocked, sign-in/sync/password manager/search-suggest off"
    }
}
#endregion

#region Sysmon
if ($Sysmon) {
    $sysmonDir        = "C:\ProgramData\Sysmon"
    $sysmonZipUrl      = "https://download.sysinternals.com/files/Sysmon.zip"
    $sysmonConfigUrl   = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"
    $sysmonZipPath     = Join-Path $sysmonDir "Sysmon.zip"
    $sysmonExePath     = Join-Path $sysmonDir "Sysmon64.exe"
    $sysmonConfigPath  = Join-Path $sysmonDir "sysmonconfig.xml"
    $sysmonServiceNames = @("Sysmon64", "Sysmon")

    if ($mode -eq "Report") {
        $svc = Get-Service -Name $sysmonServiceNames -ErrorAction SilentlyContinue | Select-Object -First 1
        Add-ReportRow "Sysmon" "Service status" "Running" $(if ($svc) { $svc.Status } else { "NotInstalled" })

        $drv = Get-Service -Name "SysmonDrv" -ErrorAction SilentlyContinue
        Add-ReportRow "Sysmon" "Kernel driver status" "Running" $(if ($drv) { $drv.Status } else { "NotInstalled" })
        Write-Host "[Sysmon] Note: applied config content isn't diffed - only install/service state is checked." -ForegroundColor DarkGray
    }
    elseif ($mode -eq "RestoreDefaults") {
        $svc = Get-Service -Name $sysmonServiceNames -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $svc) {
            Log "Sysmon" "Uninstall" "Not installed - nothing to do"
        } else {
            $exe = if (Test-Path $sysmonExePath) { $sysmonExePath } else { (Get-Command "$($svc.Name).exe" -ErrorAction SilentlyContinue).Source }
            if ($exe) {
                Start-Process -FilePath $exe -ArgumentList "-u force" -Wait -NoNewWindow
                Log "Sysmon" "Uninstall" "Removed (no Sysmon is the Windows default - it isn't a built-in component)"
            } else {
                Log "Sysmon" "Uninstall" "Service found but binary not located - remove manually, e.g. 'sysmon64 -u force'"
            }
        }
    }
    else {
        try {
            if (-not (Test-Path $sysmonDir)) { New-Item -Path $sysmonDir -ItemType Directory -Force | Out-Null }

            Write-Host "[Sysmon] Downloading Sysmon from Sysinternals..."
            Invoke-WebRequest -Uri $sysmonZipUrl -OutFile $sysmonZipPath -UseBasicParsing
            Expand-Archive -Path $sysmonZipPath -DestinationPath $sysmonDir -Force

            Write-Host "[Sysmon] Downloading SwiftOnSecurity baseline config..."
            Invoke-WebRequest -Uri $sysmonConfigUrl -OutFile $sysmonConfigPath -UseBasicParsing

            if (-not (Test-Path $sysmonExePath)) {
                throw "Sysmon64.exe not found after extracting the archive - the Sysinternals zip layout may have changed."
            }

            $svc = Get-Service -Name $sysmonServiceNames -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($svc) {
                Start-Process -FilePath $sysmonExePath -ArgumentList "-c `"$sysmonConfigPath`"" -Wait -NoNewWindow
                Log "Sysmon" "Update configuration" "Applied SwiftOnSecurity baseline config to existing install"
            } else {
                Start-Process -FilePath $sysmonExePath -ArgumentList "-accepteula -i `"$sysmonConfigPath`"" -Wait -NoNewWindow
                Log "Sysmon" "Install" "Installed with SwiftOnSecurity baseline config"
            }
        } catch {
            Log "Sysmon" "Download/Install" "Failed - $($_.Exception.Message)"
        }
    }
}
#endregion

#region Windows Update
if ($WindowsUpdate) {
    if ($mode -eq "RestoreDefaults") {
        Log "WindowsUpdate" "Restore defaults" "N/A - installing updates has no default to revert to, skipped"
    } else {
        try {
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            Write-Host "[WindowsUpdate] Searching for pending updates - this can take a minute..."
            $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")

            if ($mode -eq "Report") {
                Add-ReportRow "WindowsUpdate" "Pending updates" "0" "$($searchResult.Updates.Count)"
            }
            elseif ($searchResult.Updates.Count -eq 0) {
                Log "WindowsUpdate" "Search" "No pending updates"
            }
            else {
                $updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach ($u in $searchResult.Updates) { $updatesToDownload.Add($u) | Out-Null }

                $downloader = $updateSession.CreateUpdateDownloader()
                $downloader.Updates = $updatesToDownload
                Write-Host "[WindowsUpdate] Downloading $($updatesToDownload.Count) update(s)..."
                $downloader.Download() | Out-Null

                $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
                foreach ($u in $searchResult.Updates) { if ($u.IsDownloaded) { $updatesToInstall.Add($u) | Out-Null } }

                $installer = $updateSession.CreateUpdateInstaller()
                $installer.Updates = $updatesToInstall
                Write-Host "[WindowsUpdate] Installing $($updatesToInstall.Count) update(s)..."
                $installResult = $installer.Install()

                $rebootNote = if ($installResult.RebootRequired) { "REBOOT REQUIRED" } else { "no reboot needed" }
                Log "WindowsUpdate" "Installed $($updatesToInstall.Count) update(s)" "Result code $($installResult.ResultCode) - $rebootNote"
            }
        } catch {
            if ($mode -eq "Report") {
                Add-ReportRow "WindowsUpdate" "Pending updates" "0" "Search failed - $($_.Exception.Message)"
            } else {
                Log "WindowsUpdate" "Search/Install" "Failed - $($_.Exception.Message)"
            }
        }
    }
}
#endregion

#region Microsoft Store apps
if ($StoreApps) {
    if ($mode -eq "RestoreDefaults") {
        Log "StoreApps" "Restore defaults" "N/A - installing updates has no default to revert to, skipped"
    } else {
        try {
            $namespaceName = "root\cimv2\mdm\dmmap"
            $className = "MDM_EnterpriseModernAppManagement_AppManagement01"
            $wmiObj = Get-CimInstance -Namespace $namespaceName -ClassName $className -ErrorAction Stop
            $wmiObj | Invoke-CimMethod -MethodName UpdateScanMethod | Out-Null
            if ($mode -eq "Report") {
                Add-ReportRow "StoreApps" "Update scan" "Triggered" "Triggered"
            } else {
                Log "StoreApps" "Update all installed Store apps" "Scan/update triggered (same as 'Get updates' in Store) - runs in the background"
            }
        } catch {
            if ($mode -eq "Report") {
                Add-ReportRow "StoreApps" "Update scan" "Triggered" "Failed - $($_.Exception.Message)"
            } else {
                Log "StoreApps" "Trigger update scan" "Failed - $($_.Exception.Message)"
            }
        }
    }
}
#endregion

#region Winget-managed apps
if ($WingetUpdate) {
    if ($mode -eq "RestoreDefaults") {
        Log "WingetUpdate" "Restore defaults" "N/A - installing updates has no default to revert to, skipped"
    } else {
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $winget) {
            if ($mode -eq "Report") {
                Add-ReportRow "WingetUpdate" "Pending upgrades" "0" "winget not found on this system"
            } else {
                Log "WingetUpdate" "Upgrade all" "Skipped - winget not found on this system"
            }
        } elseif ($mode -eq "Report") {
            $rawOut = winget upgrade --include-unknown --accept-source-agreements | Out-String
            $pkgLines = ($rawOut -split "`r?`n") | Where-Object { $_ -match '\d+\.[\d\.]+\S*\s+\S' }
            Add-ReportRow "WingetUpdate" "Pending upgrades" "0" "$($pkgLines.Count)"
        } else {
            Write-Host "[WingetUpdate] Upgrading all winget-managed apps..."
            winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --include-unknown
            Log "WingetUpdate" "Upgrade all" "Done - review output above for any per-app failures"
        }
    }
}
#endregion

#region Separate admin account (opt-in, always last - see the -SeparateAdmin help for the safety checks)
if ($SeparateAdmin) {
    $adminsSid = "S-1-5-32-544"   # BUILTIN\Administrators, whatever it's called in this language

    # Default to the user signed in at the console - if this elevated window was started with
    # another account's credentials, $env:USERNAME would be that admin account, not you.
    $demoteAccount = if ($DemoteUser) {
        if ($DemoteUser.Contains('\')) { $DemoteUser } else { "$env:COMPUTERNAME\$DemoteUser" }
    } else {
        $console = (Get-CimInstance Win32_ComputerSystem).UserName
        if ($console) { $console } else { "$env:COMPUTERNAME\$env:USERNAME" }
    }
    $demoteSid = try {
        (New-Object Security.Principal.NTAccount($demoteAccount)).Translate([Security.Principal.SecurityIdentifier]).Value
    } catch { $null }

    # Membership by SID via ADSI - Get-LocalGroupMember throws on Entra ID / orphaned members.
    function Get-AdminMemberSids {
        $groupName = (Get-LocalGroup -SID $adminsSid).Name
        $group = [ADSI]"WinNT://./$groupName,group"
        @($group.Invoke("Members")) | ForEach-Object {
            $bytes = $_.GetType().InvokeMember("objectSid", "GetProperty", $null, $_, $null)
            (New-Object Security.Principal.SecurityIdentifier($bytes, 0)).Value
        }
    }
    function Test-IsAdmin($Sid) { (Get-AdminMemberSids) -contains $Sid }
    function Test-LocalPassword($Name, [securestring]$Password) {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Machine')
        try { $ctx.ValidateCredentials($Name, [Net.NetworkCredential]::new('', $Password).Password) }
        finally { $ctx.Dispose() }
    }

    if (-not $demoteSid) {
        if ($mode -eq "Report") { Add-ReportRow "SeparateAdmin" "Account to check ($demoteAccount)" "Found" "Not found" }
        else { Log "SeparateAdmin" $mode "Skipped - couldn't resolve '$demoteAccount'; pass -DemoteUser NAME" }
    }
    elseif ($mode -eq "Report") {
        Add-ReportRow "SeparateAdmin" "'$demoteAccount' is an administrator" "False" (Test-IsAdmin $demoteSid)
        $adminSids = Get-AdminMemberSids
        if ($NewAdminName) {
            $u = Get-LocalUser -Name $NewAdminName -ErrorAction SilentlyContinue
            Add-ReportRow "SeparateAdmin" "Separate admin account '$NewAdminName'" "True" ([bool]($u -and $u.Enabled -and ($adminSids -contains $u.SID.Value)))
        } else {
            $others = @(Get-LocalUser | Where-Object { $_.Enabled -and ($adminSids -contains $_.SID.Value) -and $_.SID.Value -ne $demoteSid }).Name
            $label = if ($others) { $others -join ', ' } else { 'none' }
            Add-ReportRow "SeparateAdmin" "Separate enabled admin account exists ($label)" "True" ([bool]$others)
        }
    }
    elseif ($mode -eq "RestoreDefaults") {
        if (Test-IsAdmin $demoteSid) {
            Log "SeparateAdmin" "'$demoteAccount' admin rights" "Already an administrator - nothing to do"
        } else {
            Add-LocalGroupMember -SID $adminsSid -Member $demoteSid
            $status = if (Test-IsAdmin $demoteSid) { "Restored (sign out and back in to pick it up)" } else { "FAILED - check Computer Management > Local Users and Groups" }
            Log "SeparateAdmin" "'$demoteAccount' admin rights" $status
        }
        Log "SeparateAdmin" "Admin account" "Left in place - deleting accounts isn't offered; remove it in Settings > Accounts if you no longer need it"
    }
    else {
        $name = if ($NewAdminName) { $NewAdminName } else { (Read-Host "Name for the new admin account (e.g. localadmin)").Trim() }
        $existing = Get-LocalUser -Name $name -ErrorAction SilentlyContinue

        if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,19}$') {
            Log "SeparateAdmin" "Harden" "Skipped - '$name' isn't a valid local account name (letters, digits, . _ -, max 20 characters)"
        }
        elseif ($existing -and $existing.SID.Value -eq $demoteSid) {
            Log "SeparateAdmin" "Harden" "Skipped - the new admin account can't be the account being demoted"
        }
        else {
            Write-Host ""
            Write-Host "This will $(if ($existing) {'reuse'} else {'create'}) the admin account '$name', then remove '$demoteAccount' from Administrators." -ForegroundColor Yellow
            Write-Host "Afterwards '$demoteAccount' can't approve UAC prompts on its own - you'll enter '$name' and its password instead." -ForegroundColor Yellow
            $ok = (Read-Host "Type YES to continue") -ceq "YES"
            if (-not $ok) { Log "SeparateAdmin" "Harden" "Cancelled - nothing changed" }

            if ($ok -and -not $existing) {
                $pw1 = Read-Host "Password for '$name'" -AsSecureString
                $pw2 = Read-Host "Type it again" -AsSecureString
                if ([Net.NetworkCredential]::new('', $pw1).Password -cne [Net.NetworkCredential]::new('', $pw2).Password) {
                    Log "SeparateAdmin" "Harden" "Stopped - the passwords didn't match; nothing created, '$demoteAccount' left unchanged"
                    $ok = $false
                } else {
                    try {
                        New-LocalUser -Name $name -Password $pw1 -FullName "Administrator" -Description "Separate admin account (05.Secure-Windows.ps1)" -PasswordNeverExpires -ErrorAction Stop | Out-Null
                        Add-LocalGroupMember -SID $adminsSid -Member $name -ErrorAction Stop
                        Log "SeparateAdmin" "Admin account '$name'" "Created"
                    } catch {
                        Log "SeparateAdmin" "Harden" "Stopped - couldn't create '$name' ($($_.Exception.Message)); '$demoteAccount' left unchanged"
                        $ok = $false
                    }
                }
            } elseif ($ok) {
                Log "SeparateAdmin" "Admin account '$name'" "Already exists - reusing it"
                $pw1 = Read-Host "Password for '$name' (to confirm it works)" -AsSecureString
            }

            if ($ok) {
                $user = Get-LocalUser -Name $name -ErrorAction SilentlyContinue
                if (-not ($user -and $user.Enabled -and (Test-IsAdmin $user.SID.Value))) {
                    Log "SeparateAdmin" "Harden" "Stopped - '$name' isn't an enabled administrator; '$demoteAccount' left unchanged"
                } elseif (-not (Test-LocalPassword $name $pw1)) {
                    Log "SeparateAdmin" "Harden" "Stopped - the password for '$name' didn't authenticate; '$demoteAccount' left unchanged. Reset it in Computer Management > Local Users and Groups"
                } elseif (-not (Test-IsAdmin $demoteSid)) {
                    Log "SeparateAdmin" "'$demoteAccount' admin rights" "Already a standard user"
                } else {
                    Remove-LocalGroupMember -SID $adminsSid -Member $demoteSid
                    $status = if (Test-IsAdmin $demoteSid) { "FAILED - still an administrator" } else { "Removed - now a standard user; sign out and back in to finish, and use '$name' at UAC prompts" }
                    Log "SeparateAdmin" "'$demoteAccount' admin rights" $status
                }
            }
        }
    }
}
#endregion

#region Summary
if ($mode -eq "Report") {
    if ($reportResults.Count -gt 0) {
        Write-Host "`n=== Report: Expected vs Found ===" -ForegroundColor Cyan
        $reportResults | Format-Table Category, Setting, Expected, Found, Status -AutoSize

        $mismatches = $reportResults | Where-Object Status -eq "MISMATCH"
        if ($mismatches) {
            Write-Host "$($mismatches.Count) setting(s) do not match the hardened baseline:" -ForegroundColor Yellow
            foreach ($m in $mismatches) {
                Write-Host " - [$($m.Category)] $($m.Setting): expected '$($m.Expected)', found '$($m.Found)'" -ForegroundColor Red
            }
        } else {
            Write-Host "All checked settings match the hardened baseline." -ForegroundColor Green
        }
    }
} elseif ($results.Count -gt 0) {
    Write-Host "`n=== Summary ($mode) ===" -ForegroundColor Cyan
    $results | Format-Table -AutoSize
    if ($mode -eq "Harden") {
        Write-Host "Some changes (BitLocker, ASR audit-mode rule, RDP) may need a review or reboot to take full effect." -ForegroundColor Yellow
    } else {
        Write-Host "Some reverts (BitLocker decryption, service restarts) may take time or need a reboot to fully apply." -ForegroundColor Yellow
    }
}
#endregion
