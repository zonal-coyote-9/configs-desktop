<#
.SYNOPSIS
    Replaces Windows Terminal's settings folder with a link into OneDrive, so Terminal
    settings sync between machines.

.DESCRIPTION
    Deletes %LocalAppData%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState and
    recreates it as a symbolic link to %OneDriveConsumer%\Apps\Terminal\Win. Only run it once
    OneDrive is installed and syncing. Running with no parameters shows this help and changes
    nothing.

.PARAMETER Run
    Delete the existing settings folder and create the link.

.EXAMPLE
    .\TermSetup.ps1 -Run
#>

param(
    [switch]$Run
)

if (-not $Run) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

Remove-Item -Path $Env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState -Force -Recurse
New-Item -ItemType SymbolicLink -Path "$Env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState" -Target "$Env:OneDriveConsumer\Apps\Terminal\Win"