<#
.SYNOPSIS
	Checks the time until Easter Sunday
.DESCRIPTION
	This PowerShell script checks the time until Easter Sunday and replies by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-easter-sunday
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Now = [DateTime]::Now
	$Easter = [Datetime]()
	if ($Now -lt $Easter) {
		$Diff = $Easter – $Now
		&  
	} else {
		$Diff = $Now - $Easter
		&  
	}
	exit 0 # success
} catch {
	
	exit 1
}
