<#
.SYNOPSIS
	Determines the week number 
.DESCRIPTION
	This PowerShell script determines and speaks the current week number by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-week.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$WeekNo = (Get-Date -UFormat %V)
	&  
	exit 0 # success
} catch {
	
	exit 1
}
