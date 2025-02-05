<#
.SYNOPSIS
	Closes the Microsoft Outlook app
.DESCRIPTION
	This PowerShell script closes the Microsoft Outlook email application gracefully.
.EXAMPLE
	PS> ./close-outlook.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

TaskKill /im outlook.exe
if ($lastExitCode -ne ) {
	&  
	exit 1
}
exit 0 # success
