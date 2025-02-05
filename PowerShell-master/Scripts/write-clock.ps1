<#
.SYNOPSIS
	Writes an ASCII clock
.DESCRIPTION
	This PowerShell script writes the current time as ASCII clock.
.EXAMPLE
	PS> ./write-clock.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	[system.threading.thread]::currentthread.currentculture = [system.globalization.cultureinfo]
	$Weekday = Get-Date -UFormat 
	$Date = Get-Date -UFormat 
	$Week = Get-Date -UFormat 

	Clear-Host
	&  
	Write-Output 
	&  
	Write-Output 
	&  
	Write-Output 

	$StartPosition = $HOST.UI.RawUI.CursorPosition
	while ($true) {
		$Time = Get-Date -format  
		&  
		Write-Output 
		Start-Sleep -seconds 1
		$HOST.UI.RawUI.CursorPosition = $StartPosition
	}
	exit 0 # success
} catch {
	
	exit 1
}
