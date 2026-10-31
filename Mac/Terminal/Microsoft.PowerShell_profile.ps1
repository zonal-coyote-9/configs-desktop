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
