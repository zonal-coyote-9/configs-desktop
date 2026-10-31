# Code Snippets

Function Get-ExternalIP {
	(Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

}

# Import other function files

. ./Functions/Generate-Password.ps1
. ./Functions/Generate-Username.ps1
. ./Functions/ConvertTo-Jpeg.ps1
. ./Functions/PhotoOrg.ps1
. ./Functions/Sort-Screenshots.ps1
. ./Functions/Sort-Downloads.ps1