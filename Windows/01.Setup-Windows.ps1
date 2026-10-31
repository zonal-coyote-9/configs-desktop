<#
.SYNOPSIS
    First-run Windows setup: offers to rename the PC, then installs apps picked from a menu
    per category via winget.

.DESCRIPTION
    Running with no parameters shows this help and changes nothing. Pass -Run (or
    -MachineName / -InstallAll) to actually run setup.

.PARAMETER Run
    Run setup, asking for anything not given on the command line.

.PARAMETER MachineName
    Computer name to set (letters, digits and hyphens, max 15 characters). Needs an elevated
    shell. If omitted, you're asked - but only while the PC still has its default
    DESKTOP-XXXXXXX / LAPTOP-XXXXXXX name.

.PARAMETER InstallAll
    Skip the app menus and install every app in every category.

.PARAMETER SkipPostInstallSteps
    Stop after the app installs - skip the environment-specific Terminal setup, certificate
    installs and drive mapping at the end.

.EXAMPLE
    .\01.Setup-Windows.ps1 -Run
    Asks for the computer name (while it's still the default) and which apps to install.

.EXAMPLE
    .\01.Setup-Windows.ps1 -InstallAll

.EXAMPLE
    .\01.Setup-Windows.ps1 -MachineName WORKSTATION-01 -InstallAll
    Renames the PC and installs every app with no prompts.
#>

[CmdletBinding()]
param(
    [switch]$Run,
    [string]$MachineName,
    [switch]$InstallAll,
    [switch]$SkipPostInstallSteps
)

if (-not ($Run -or $MachineName -or $InstallAll)) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

$scriptRoot = Split-Path -Parent $PSCommandPath

$categories = @(
    [pscustomobject]@{
        Name = 'Comms'
        Apps = @(
            [pscustomobject]@{ Name = 'Discord'; Id = 'Discord.Discord' }
            [pscustomobject]@{ Name = 'Slack'; Id = 'SlackTechnologies.Slack' }
            [pscustomobject]@{ Name = 'Signal'; Id = 'OpenWhisperSystems.Signal' }
            [pscustomobject]@{ Name = 'Microsoft Teams'; Id = 'Microsoft.Teams' }
            [pscustomobject]@{ Name = 'BlueBubbles'; Id = '9p3xf8kj0lsm' }
        )
    },
    [pscustomobject]@{
        Name = 'Media'
        Apps = @(
            [pscustomobject]@{ Name = 'Spotify'; Id = 'Spotify.Spotify' }
            [pscustomobject]@{ Name = 'foobar2000'; Id = 'PeterPawlowski.foobar2000' }
            [pscustomobject]@{ Name = 'AirParrot 3'; Id = 'Squirrels.AirParrot3' }
            [pscustomobject]@{ Name = 'VLC'; Id = 'VideoLAN.VLC' }
            [pscustomobject]@{ Name = 'Jellyfin Media Player'; Id = 'Jellyfin.JellyfinMediaPlayer' }
            [pscustomobject]@{ Name = 'yt-dlp'; Id = 'yt-dlp.yt-dlp' }
        )
    },
    [pscustomobject]@{
        Name = 'Office Apps'
        Apps = @(
            [pscustomobject]@{ Name = 'Microsoft 365'; Id = 'Microsoft.Office' }
            [pscustomobject]@{ Name = 'Obsidian'; Id = 'Obsidian.Obsidian' }
        )
    },
    [pscustomobject]@{
        Name = 'Utilities'
        Apps = @(
            [pscustomobject]@{ Name = 'PowerToys'; Id = 'XP89DCGQ3K6VLD' }
            [pscustomobject]@{ Name = 'Random Dad Jokes for Cmd Pal'; Id = 'MichaelJolley.RandomDadJokesForCmdPal' }
            [pscustomobject]@{ Name = 'Duet Display'; Id = 'Kairos.DuetDisplay' }
            [pscustomobject]@{ Name = 'Fastfetch'; Id = 'Fastfetch-cli.Fastfetch' }
            [pscustomobject]@{ Name = 'Media Controls for Command Palette'; Id = 'JiriPolasek.MediaControlsforCommandPalette' }
            [pscustomobject]@{ Name = 'Bitwarden'; Id = 'Bitwarden.Bitwarden' }
            [pscustomobject]@{ Name = 'Bitwarden CLI'; Id = 'Bitwarden.CLI' }
            [pscustomobject]@{ Name = 'Ubiquiti WiFi Man Desktop'; Id = 'Ubiquiti.WiFimanDesktop' }
            [pscustomobject]@{ Name = 'Windows Terminal'; Id = 'Microsoft.WindowsTerminal' }
            [pscustomobject]@{ Name = 'Wireshark'; Id = 'WiresharkFoundation.Wireshark' }
            [pscustomobject]@{ Name = 'Windows App'; Id = 'Microsoft.WindowsApp' }
            [pscustomobject]@{ Name = 'OneDrive'; Id = 'Microsoft.OneDrive' }
            [pscustomobject]@{ Name = 'Microsoft Edge'; Id = 'Microsoft.Edge' }
            [pscustomobject]@{ Name = '7-Zip'; Id = '7zip.7zip' }
            [pscustomobject]@{ Name = 'balenaEtcher'; Id = 'Balena.Etcher' }
            [pscustomobject]@{ Name = 'Raspberry Pi Imager'; Id = 'RaspberryPiFoundation.RaspberryPiImager' }
        )
    },
    [pscustomobject]@{
        Name = 'Dev'
        Apps = @(
            [pscustomobject]@{ Name = 'Git'; Id = 'Git.Git' }
            [pscustomobject]@{ Name = 'PowerShell'; Id = 'Microsoft.PowerShell' }
            [pscustomobject]@{ Name = 'Azure CLI'; Id = 'Microsoft.AzureCLI' }
            [pscustomobject]@{ Name = 'Visual Studio Code'; Id = 'Microsoft.VisualStudioCode' }
            [pscustomobject]@{ Name = 'Python 3.14'; Id = 'Python.Python.3.14' }
            [pscustomobject]@{ Name = '.NET Runtime 10'; Id = 'Microsoft.DotNet.Runtime.10' }
            [pscustomobject]@{ Name = 'AzCopy'; Id = 'Microsoft.Azure.AZCopy.10' }
            [pscustomobject]@{ Name = 'Azure Storage Explorer'; Id = 'Microsoft.Azure.StorageExplorer' }
            [pscustomobject]@{ Name = 'Royal TS'; Id = 'RoyalApps.RoyalTS.7' }
        )
    },
    [pscustomobject]@{
        Name = 'Creative'
        Apps = @(
            [pscustomobject]@{ Name = 'Paint.NET'; Id = 'dotPDN.PaintDotNet' }
            [pscustomobject]@{ Name = 'Adobe Acrobat Reader'; Id = 'Adobe.Acrobat.Reader.64-bit' }
            [pscustomobject]@{ Name = 'Affinity'; Id = 'Canva.Affinity' }
            [pscustomobject]@{ Name = 'draw.io'; Id = 'JGraph.Draw' }
        )
    },
    [pscustomobject]@{
        Name = 'Others'
        Apps = @(
            [pscustomobject]@{ Name = 'Steam'; Id = 'Valve.Steam' }
            [pscustomobject]@{ Name = 'Bambu Studio'; Id = 'Bambulab.Bambustudio' }
            [pscustomobject]@{ Name = 'GeForce NOW'; Id = 'Nvidia.GeForceNow' }
        )
    },
    [pscustomobject]@{
        Name = 'AI'
        Apps = @(
            [pscustomobject]@{ Name = 'Claude'; Id = 'Anthropic.Claude' }
            [pscustomobject]@{ Name = 'Claude Code'; Id = 'Anthropic.ClaudeCode' }
            [pscustomobject]@{ Name = 'ChatGPT'; Id = '9NT1R1C2HH7J' }
        )
    }
)

function Show-CategoryMenu {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CategoryName,

        [Parameter(Mandatory = $true)]
        [object[]]$Apps
    )

    Write-Host "" 
    Write-Host "=== $CategoryName ===" -ForegroundColor Cyan
    Write-Host 'Select apps to install for this category.'
    Write-Host '  A = all apps'
    Write-Host '  S = skip this category'
    Write-Host '  Q = quit'

    for ($index = 0; $index -lt $Apps.Count; $index++) {
        $app = $Apps[$index]
        Write-Host ("  {0}. {1} ({2})" -f ($index + 1), $app.Name, $app.Id)
    }

    $selectionInput = Read-Host 'Enter selection (for example: 1,3 or A)'

    if ([string]::IsNullOrWhiteSpace($selectionInput)) {
        return @()
    }

    $normalizedSelection = $selectionInput.Trim().ToLowerInvariant()

    switch ($normalizedSelection) {
        'a' { return $Apps }
        'all' { return $Apps }
        's' { return @() }
        'skip' { return @() }
        'q' { throw 'Selection cancelled by user.' }
        'quit' { throw 'Selection cancelled by user.' }
    }

    $selectedApps = @()
    foreach ($token in ($selectionInput -split ',')) {
        $candidate = $token.Trim()
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        if ($candidate -match '^\d+$') {
            $appIndex = [int]$candidate - 1
            if ($appIndex -ge 0 -and $appIndex -lt $Apps.Count) {
                $selectedApps += $Apps[$appIndex]
            }
            else {
                Write-Warning "Ignoring invalid selection '$candidate'."
            }
        }
        else {
            Write-Warning "Ignoring invalid selection '$candidate'."
        }
    }

    return $selectedApps
}

function Install-WingetApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    Write-Host "Installing $Name..." -ForegroundColor Green
    & winget install --id $Id --accept-package-agreements --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Installation failed for $Name (exit code $LASTEXITCODE)."
    }
}

function Set-MachineName([string]$RequestedName) {
    # Same idea as the Mac/Fedora setup scripts: without -MachineName, only prompt while the
    # PC still has Windows' auto-generated name, so re-running setup doesn't ask again. A name
    # passed with -MachineName is applied even if the PC was renamed before.
    if (-not $RequestedName -and $env:COMPUTERNAME -notmatch '^(DESKTOP|LAPTOP)-[A-Z0-9]{7}$') {
        Write-Host "Computer name already set to '$env:COMPUTERNAME', skipping" -ForegroundColor Yellow
        return
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "Renaming the PC needs an elevated shell - re-run as Administrator, or use Settings > System > About > Rename this PC."
        return
    }

    $newName = if ($RequestedName) { $RequestedName.Trim() } else { (Read-Host "Enter machine name [$env:COMPUTERNAME]").Trim() }
    if ([string]::IsNullOrWhiteSpace($newName) -or $newName -eq $env:COMPUTERNAME) {
        Write-Host "Keeping computer name '$env:COMPUTERNAME'." -ForegroundColor Yellow
        return
    }
    # NetBIOS names: letters, digits and hyphens, at most 15 characters.
    if ($newName -notmatch '^[A-Za-z0-9-]{1,15}$') {
        Write-Warning "'$newName' isn't a valid computer name (letters, digits, hyphens, max 15 characters) - skipping rename."
        return
    }
    Rename-Computer -NewName $newName -Force
    Write-Host "Computer will be renamed to '$newName' after the next restart." -ForegroundColor Green
}

Set-MachineName $MachineName

$selectedByCategory = @{}

if ($InstallAll) {
    Write-Host '-InstallAll: installing every app in every category, no menus.' -ForegroundColor Cyan
}

try {
    foreach ($category in $categories) {
        $selectedApps = if ($InstallAll) { $category.Apps } else { Show-CategoryMenu -CategoryName $category.Name -Apps $category.Apps }
        $selectedByCategory[$category.Name] = $selectedApps
    }
}
catch {
    Write-Host 'Selection cancelled. Exiting.' -ForegroundColor Yellow
    exit 1
}

foreach ($category in $categories) {
    $selectedApps = $selectedByCategory[$category.Name]

    if ($null -eq $selectedApps -or $selectedApps.Count -eq 0) {
        Write-Host "Skipping $($category.Name)." -ForegroundColor Yellow
        continue
    }

    Write-Host "" 
    Write-Host "Installing apps for $($category.Name)..." -ForegroundColor Yellow

    foreach ($app in $selectedApps) {
        Install-WingetApp -Name $app.Name -Id $app.Id
    }
}

Write-Host ""
Write-Host 'App installs done. Next: run .\02.Configure-Windows.ps1 -Run to apply Windows preference settings.' -ForegroundColor Cyan

if ($SkipPostInstallSteps) {
    Write-Host 'Skipping post-install setup steps.' -ForegroundColor Yellow
    exit 0
}

Write-Host "" 
Write-Host 'Running post-install setup...' -ForegroundColor Cyan

$terminalSetupScript = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot '..\..\Apps\Terminal\Win\TermSetup.ps1'))
if (Test-Path $terminalSetupScript) {
    # Newer copies of TermSetup.ps1 only show help unless given -Run; older ones don't accept it.
    if ((Get-Command $terminalSetupScript).Parameters.ContainsKey('Run')) {
        & $terminalSetupScript -Run
    }
    else {
        & $terminalSetupScript
    }
}
else {
    Write-Warning "Terminal setup script not found at $terminalSetupScript"
}