Import-Module C:\Tools\JITShell\JITShell.psd1
Import-Module C:\Tools\dSMS.Functions\dSMS.Functions.psm1
Set-Location C:\Tools
. C:\CeiseData\Utils\CeiseCommonUtils.ps1
$CeiseData = Import-PowerShellDataFile "C:\CeiseData\CeiseData.psd1"

function prompt{
	$Date = Get-Date -Format "ddMMyyy HH:mm:ss"
	$CWD = Get-Location
	$WhoAmI = $ENV:USERNAME
	$Comp = $ENV:COMPUTERNAME

	if ($H=Get-History) {
		$executionTime = ($H[-1].EndExecutionTime - $H[-1].StartExecutionTime).Totalmilliseconds
	}

	"$($Date)|$executionTime|$Comp\$WhoAmI|PS $($CWD) > "
}
