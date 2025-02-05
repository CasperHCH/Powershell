<#
.SYNOPSIS
	Determines the current day 
.DESCRIPTION
	This PowerShell script determines and speaks the current day by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-day
	✔️ It's Sunday.
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	[system.threading.thread]::currentthread.currentculture=[system.globalization.cultureinfo]
	$Weekday = (Get-Date -format )
	&  
	exit 0 # success
} catch {
	
	exit 1
}
