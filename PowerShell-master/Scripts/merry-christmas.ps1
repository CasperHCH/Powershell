<#
.SYNOPSIS
	Replies to 
.DESCRIPTION
	This PowerShell script replies to 'Merry Christmas' by text-to-speech (TTS).
.EXAMPLE
	PS> ./merry-christmas.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

$Reply = ,  | Get-Random

&  
exit 0 # success
