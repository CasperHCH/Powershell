<#
.SYNOPSIS
	Checks the power status
.DESCRIPTION
	This PowerShell script queries the power status and prints it.
.EXAMPLE
	PS> ./check-power.ps1
	⚠️ Battery at 9% · 54 min remaining · power scheme 'HP Optimized' 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		$reply =  # TODO, just guessing :-)
	} else {
		Add-Type -Assembly System.Windows.Forms
		$details = [System.Windows.Forms.SystemInformation]::PowerStatus
		[int]$percent = 100 * $details.BatteryLifePercent
		[int]$remaining = $details.BatteryLifeRemaining / 60
		if ($details.PowerLineStatus -eq ) {
			if ($details.BatteryChargeStatus -eq ) {
				$reply = 
			} elseif ($percent -ge 95) {
				$reply = 
			} else {
				$reply = 
			}
		} else { # must be offline
			if (($remaining -eq 0) -and ($percent -gt 90)) {
				$reply = 
			} elseif ($remaining -eq 0) {
				$reply = 
			} elseif ($remaining -le 5) {
				$reply = 
			} elseif ($remaining -le 30) {
				$reply = 
			} elseif ($percent -lt 10) {
				$reply = 
			} elseif ($percent -ge 80) {
				$reply = 
			} else {
				$reply = 
			}
		}
		$powerScheme = (powercfg /getactivescheme)
		$powerScheme = $powerScheme -Replace ,
		$powerScheme = $powerScheme -Replace ,
		$reply += 
	}
	Write-Output $reply
	exit 0 # success
} catch {
	
	exit 1
}
