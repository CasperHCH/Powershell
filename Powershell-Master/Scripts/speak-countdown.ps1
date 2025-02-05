<#
.SYNOPSIS
	Speaks a countdown by text-to-speech
.DESCRIPTION
	This PowerShell script speaks a countdown by text-to-speech (TTS) starting from a given number.
.PARAMETER StartNumber
	Specifies the number to start from (10 by default)
.EXAMPLE
	PS> ./speak-countdown.ps1 60
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([int]$StartNumber = 10)

try {
	for ([int]$i = $StartNumber; $i -gt 0; $i--) {
		&  $i
		Start-Sleep -milliseconds 200
	}
	&  
	exit 0 # success
} catch {
	
	exit 1
}
