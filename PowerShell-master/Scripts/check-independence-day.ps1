<#
.SYNOPSIS
	Checks the time until Independence Day
.DESCRIPTION
	This PowerShell script checks the time until Indepence Day and replies by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-independence-day.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Now = [DateTime]::Now
	$IndependenceDay = [Datetime]( + $Now.Year)
	if ($Now -lt $IndependenceDay) {
		$Diff = $IndependenceDay – $Now
		&  
	} else {
		$Diff = $Now - $IndependenceDay
		&  
	}
	exit 0 # success
} catch {
	
	exit 1
}
