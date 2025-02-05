<#
.SYNOPSIS
	Checks the ISS position
.DESCRIPTION
	This PowerShell script queries the position of the International Space Station (ISS) and replies by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-iss-position
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$ISS = (Invoke-WebRequest  -userAgent  -useBasicParsing).Content | ConvertFrom-Json

	&  
	exit 0 # success
} catch {
	
	exit 1
}
