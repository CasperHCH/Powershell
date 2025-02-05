<#
.SYNOPSIS
	Checks the uptime 
.DESCRIPTION
	This PowerShell script queries the computer's uptime and prints it.
.EXAMPLE
	PS> ./check-uptime.ps1
	✅ Up for 2 days, 20 hours, 10 minutes
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		$Uptime = (Get-Uptime)
	} else {
		$BootTime = Get-WinEvent -ProviderName eventlog | Where-Object {$_.Id -eq 6005} | Select-Object TimeCreated -First 1 
		$Uptime = New-TimeSpan -Start $BootTime.TimeCreated.Date -End (Get-Date)
	}
	$Reply = 
	$Days = $Uptime.Days
	if ($Days -eq ) {
		$Reply += 
	} elseif ($Days -ne ) {
		$Reply += 
	}

	$Hours = $Uptime.Hours
	if ($Hours -eq ) {
		$Reply += 
	} elseif ($Hours -ne ) {
		$Reply += 
	}

	$Minutes = $Uptime.Minutes 
	if ($Minutes -eq ) {
		$Reply += 
	} else {
		$Reply += 
	}
	Write-Host $Reply
	exit 0 # success
} catch {
	
	exit 1
}
