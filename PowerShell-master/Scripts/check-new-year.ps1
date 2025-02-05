<#
.SYNOPSIS
	Checks the time until New Year
.DESCRIPTION
	This PowerShell script checks the time until New Year and replies by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-new-year
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Now = [DateTime]::Now
	$NewYear = [Datetime]( + $Now.Year)
	$Days = ($NewYear – $Now).Days + 1
	if ($Days -gt 1) {
		&  
	} elseif ($Days -eq 1) {
		&  
	}
	exit 0 # success
} catch {
	
	exit 1
}
