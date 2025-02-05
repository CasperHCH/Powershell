<#
.SYNOPSIS
	Replies to 
.DESCRIPTION
	This PowerShell script rolls a dice and returns the number by text-to-speech (TTS).
.EXAMPLE
	PS> ./roll-a-dice
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

$Reply = , , ,  | Get-Random
$Number = , , , , ,  | Get-Random

&  
exit 0 # success
