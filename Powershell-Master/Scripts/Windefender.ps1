<#
.SYNOPSIS
	Windows defender in powershell
.DESCRIPTION
	This script can enable disable and show windows defender real time monitoring!
.EXAMPLE
	PS> ./Windefender.ps1
.LINK
	https://github.com/pakoti/Awesome_Sysadmin
.NOTES
	Author: Dark Master | License: CC0-1,0
#>



$defender = Get-MpPreference

$userInput = Read-Host 

switch($userInput) {
1 {
$defender.DisableRealtimeMonitoring = $true
$defender | Set-MpPreference
Write-Host 
break
}
2 {
$defender.DisableRealtimeMonitoring = $false
$defender | Set-MpPreference
Write-Host 
break
}
3 {
if($defender.DisableRealtimeMonitoring) {
Write-Host 
} else {
Write-Host 
}
break
}
default {
Write-Host 
break
}
}
