<#
.SYNOPSIS
    First-run preference tweaks for Windows - the counterpart to 02.Configure-Mac.py.

.DESCRIPTION
    Applies per-user settings: 24-hour time and always showing file extensions in File
    Explorer. Run after 01.Setup-Windows.ps1, as your normal user (no elevation needed -
    everything here is per-user, under HKCU). Safe to re-run.
    Running with no parameters shows this help and changes nothing.

.PARAMETER Run
    Apply the settings.

.EXAMPLE
    .\02.Configure-Windows.ps1 -Run
#>

[CmdletBinding()]
param(
    [switch]$Run
)

if (-not $Run) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

function Set-24HourTime {
    # Per-user regional format settings (Settings > Time & language > Language & region >
    # Regional format). The taskbar clock uses sShortTime. Takes effect after sign-out.
    $international = 'HKCU:\Control Panel\International'
    Set-ItemProperty -Path $international -Name 'sShortTime' -Value 'HH:mm'
    Set-ItemProperty -Path $international -Name 'sTimeFormat' -Value 'HH:mm:ss'
    Set-ItemProperty -Path $international -Name 'iTime' -Value '1'
    Set-ItemProperty -Path $international -Name 'iTLZero' -Value '1'
    Write-Host '24-hour time enabled (sign out and back in to apply everywhere).' -ForegroundColor Green
}

function Set-ExplorerDefaults {
    # Always show file extensions, same as the Mac setup's AppleShowAllExtensions - also
    # keeps 'invoice.pdf.exe'-style names from hiding their real type.
    $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty -Path $advanced -Name 'HideFileExt' -Value 0 -Type DWord
    Write-Host 'File extensions shown in File Explorer (restart Explorer or sign out to apply).' -ForegroundColor Green
}

Set-24HourTime
Set-ExplorerDefaults
