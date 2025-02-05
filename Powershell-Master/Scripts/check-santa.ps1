<#
.SYNOPSIS
	Checks the time until Saint Nicholas Day
.DESCRIPTION
	This PowerShell script checks the time until Saint Nicholas Day and replies by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-santa
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Now = [DateTime]::Now
	$Diff = [Datetime]( + $Now.Year) – $Now

	&  
	exit 0 # success
} catch {
	
	exit 1
}
