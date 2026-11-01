<#
.SYNOPSIS
    Installs pending Windows Update, Microsoft Store, and winget-managed app updates.

.DESCRIPTION
    Pass -Run to install updates or -Report to show pending updates without installing
    them. Must be run from an elevated (Administrator) PowerShell session. Running with
    no parameters shows this help and changes nothing.

.PARAMETER Run
    Install all pending updates.

.PARAMETER Report
    List what's pending without installing anything.

.EXAMPLE
    .\04.Update-Windows.ps1 -Run

.EXAMPLE
    .\04.Update-Windows.ps1 -Report
#>

[CmdletBinding()]
param(
    [switch]$Run,
    [switch]$Report
)

if (-not ($Run -or $Report)) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Re-launch PowerShell elevated."
    exit 1
}

$mode = if ($Report) { "Report" } else { "Run" }
$results = [System.Collections.Generic.List[object]]::new()
$reportResults = [System.Collections.Generic.List[object]]::new()

function Add-Result($Category, $Action, $Status) {
    $results.Add([pscustomobject]@{ Category = $Category; Action = $Action; Status = $Status })
    Write-Host "[$Category] $Action -> $Status"
}

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

#region Windows Update
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    Write-Host "[WindowsUpdate] Searching for pending updates - this can take a minute..."
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")

    if ($Report) {
        Add-ReportRow "WindowsUpdate" "Pending updates" "0" "$($searchResult.Updates.Count)"
    }
    elseif ($searchResult.Updates.Count -eq 0) {
        Add-Result "WindowsUpdate" "Search" "No pending updates"
    }
    else {
        $updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $searchResult.Updates) { $updatesToDownload.Add($update) | Out-Null }

        $downloader = $updateSession.CreateUpdateDownloader()
        $downloader.Updates = $updatesToDownload
        Write-Host "[WindowsUpdate] Downloading $($updatesToDownload.Count) update(s)..."
        $downloader.Download() | Out-Null

        $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $searchResult.Updates) {
            if ($update.IsDownloaded) { $updatesToInstall.Add($update) | Out-Null }
        }

        $installer = $updateSession.CreateUpdateInstaller()
        $installer.Updates = $updatesToInstall
        Write-Host "[WindowsUpdate] Installing $($updatesToInstall.Count) update(s)..."
        $installResult = $installer.Install()

        $rebootNote = if ($installResult.RebootRequired) { "REBOOT REQUIRED" } else { "no reboot needed" }
        Add-Result "WindowsUpdate" "Installed $($updatesToInstall.Count) update(s)" "Result code $($installResult.ResultCode) - $rebootNote"
    }
} catch {
    if ($Report) {
        Add-ReportRow "WindowsUpdate" "Pending updates" "0" "Search failed - $($_.Exception.Message)"
    } else {
        Add-Result "WindowsUpdate" "Search/Install" "Failed - $($_.Exception.Message)"
    }
}
#endregion

#region Microsoft Store apps
try {
    $namespaceName = "root\cimv2\mdm\dmmap"
    $className = "MDM_EnterpriseModernAppManagement_AppManagement01"
    $wmiObj = Get-CimInstance -Namespace $namespaceName -ClassName $className -ErrorAction Stop
    $wmiObj | Invoke-CimMethod -MethodName UpdateScanMethod | Out-Null
    if ($Report) {
        Add-ReportRow "StoreApps" "Update scan" "Triggered" "Triggered"
    } else {
        Add-Result "StoreApps" "Update all installed Store apps" "Scan/update triggered (same as 'Get updates' in Store) - runs in the background"
    }
} catch {
    if ($Report) {
        Add-ReportRow "StoreApps" "Update scan" "Triggered" "Failed - $($_.Exception.Message)"
    } else {
        Add-Result "StoreApps" "Trigger update scan" "Failed - $($_.Exception.Message)"
    }
}
#endregion

#region Winget-managed apps
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    if ($Report) {
        Add-ReportRow "WingetUpdate" "Pending upgrades" "0" "winget not found on this system"
    } else {
        Add-Result "WingetUpdate" "Upgrade all" "Skipped - winget not found on this system"
    }
} elseif ($Report) {
    try {
        $rawOut = winget upgrade --include-unknown --accept-source-agreements | Out-String
        $pkgLines = ($rawOut -split "`r?`n") | Where-Object { $_ -match '\d+\.[\d\.]+\S*\s+\S' }
        Add-ReportRow "WingetUpdate" "Pending upgrades" "0" "$($pkgLines.Count)"
    } catch {
        Add-ReportRow "WingetUpdate" "Pending upgrades" "0" "Search failed - $($_.Exception.Message)"
    }
} else {
    Write-Host "[WingetUpdate] Upgrading all winget-managed apps..."
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --include-unknown
    Add-Result "WingetUpdate" "Upgrade all" "Done - review output above for any per-app failures"
}
#endregion

#region Summary
if ($Report) {
    if ($reportResults.Count -gt 0) {
        Write-Host "`n=== Report: Expected vs Found ===" -ForegroundColor Cyan
        $reportResults | Format-Table Category, Setting, Expected, Found, Status -AutoSize

        $mismatches = $reportResults | Where-Object Status -eq "MISMATCH"
        if ($mismatches) {
            Write-Host "$($mismatches.Count) update check(s) need attention:" -ForegroundColor Yellow
            foreach ($mismatch in $mismatches) {
                Write-Host " - [$($mismatch.Category)] $($mismatch.Setting): $($mismatch.Found)" -ForegroundColor Red
            }
        } else {
            Write-Host "All update checks match the expected state." -ForegroundColor Green
        }
    }
} elseif ($results.Count -gt 0) {
    Write-Host "`n=== Summary ($mode) ===" -ForegroundColor Cyan
    $results | Format-Table -AutoSize
    Write-Host "Some Windows updates may need a restart to finish; save your work and restart if prompted." -ForegroundColor Yellow
}
#endregion
