<#
.SYNOPSIS
	Writes the current date 
.DESCRIPTION
	This PowerShell script determines and writes the current date.
.EXAMPLE
	PS> ./write-date
	📅12/25/2022
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	[system.threading.thread]::currentthread.currentculture = [system.globalization.cultureinfo]
	$CurrentDate = (Get-Date).ToShortDateString()
	
	exit 0 # success
} catch {
	
	exit 1
}
