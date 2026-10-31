<#
.SYNOPSIS
    Creates a set of named Microsoft Edge profiles.

.DESCRIPTION
    Launches Edge once per profile name with its own profile directory, which creates the
    profile. Running with no parameters shows this help and changes nothing.

.PARAMETER Run
    Create the default profiles: Personal, School, ADM-CCE, ADM-TPM, ADM-Nativemode.

.PARAMETER Profiles
    Create these profiles instead of the defaults.

.EXAMPLE
    .\New-EdgeProfile.ps1 -Run

.EXAMPLE
    .\New-EdgeProfile.ps1 -Profiles Work, Banking
#>

param (
    [switch]$Run,
    $Profiles = ("Personal","School","ADM-CCE","ADM-TPM","ADM-Nativemode")
)

if (-not ($Run -or $PSBoundParameters.ContainsKey('Profiles'))) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

Foreach ($Profile in $Profiles) {
	Write-Host "Creating profile: $Profile"
	$profilePath = "profile-" + $Profile
	$proc = Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "--profile-directory=$profilePath --no-first-run --no-default-browser-check --flag-switches-begin --flag-switches-end --site-per-process" -passThru

	Write-Output "Profile $Profile created, go to edge://settings/profiles"
}

