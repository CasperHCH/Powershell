<#
.SYNOPSIS
	Hibernates the computer
.DESCRIPTION
	This PowerShell script hibernates the local computer immediately. 
.EXAMPLE
	PS> ./hibernate.ps1
	It's 5:04 PM, going to sleep now... 😴💤
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	[system.threading.thread]::currentThread.currentCulture = [system.globalization.cultureInfo]
	$CurrentTime = $((Get-Date).ToShortTimeString())
	Write-Host 
	Start-Sleep -milliseconds 500
	& rundll32.exe powrprof.dll,SetSuspendState 1,1,0 # bHibernate,bForce,bWakeupEventsDisabled
	exit 0 # success
} catch {
	
	exit 1
}
