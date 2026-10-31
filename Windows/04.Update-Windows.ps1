<#
.SYNOPSIS
    Recurring maintenance - installs pending Windows Update, Microsoft Store, and
    winget-managed app updates. The Windows counterpart to 04.Update-Mac.py and
    04.Update-Fedora.sh.

.DESCRIPTION
    A thin wrapper around 05.Secure-Windows.ps1's three update categories, so there's one
    obvious script to run for updates on every platform. Pass -Report to list what's
    pending without installing anything. Must be run from an elevated (Administrator)
    PowerShell session. Running with no parameters shows this help and changes nothing.

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

$secureScript = Join-Path (Split-Path -Parent $PSCommandPath) '05.Secure-Windows.ps1'
& $secureScript -WindowsUpdate -StoreApps -WingetUpdate -Report:$Report
