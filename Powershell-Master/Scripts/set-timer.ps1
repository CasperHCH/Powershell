<#
.SYNOPSIS
	Sets a timer for a countdown
.DESCRIPTION
	This PowerShell script sets a timer for a countdown.
.PARAMETER Seconds
	Specifies the number of seconds
.EXAMPLE
	PS> ./set-timer 60
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([int]$Seconds = 0)

try {
	if ($Seconds -eq 0 ) { [int]$Seconds = read-host  }

	for ($i = $Seconds; $i -gt 0; $i--) {
		Clear-Host
		./write-big 
		Start-Sleep -seconds 1
	}

	
	exit 0 # success
} catch {
	
	exit 1
}
