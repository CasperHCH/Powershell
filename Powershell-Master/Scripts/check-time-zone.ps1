<#
.SYNOPSIS
	Checks the time zone
.DESCRIPTION
	This PowerShell script queries the time zone and prints it.
.EXAMPLE
	PS> ./check-time-zone.ps1
	✅ 11:13 AM W. Europe Summer Time (UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna (+01:00 DST)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	[system.threading.thread]::currentThread.currentCulture = [system.globalization.cultureInfo]
	$Time = $((Get-Date).ToShortTimeString())
	$TZ = (Get-Timezone)
	if ($TZ.SupportsDaylightSavingTime) {
		$TZName = $TZ.DaylightName
		$DST=
	} else {
		$TZName = $TZ.StandardName
		$DST=
	}
	Write-Host 
	exit 0 # success
} catch {
	
	exit 1
}
