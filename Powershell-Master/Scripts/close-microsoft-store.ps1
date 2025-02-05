<#
.SYNOPSIS
	Closes the Microsoft Store app
.DESCRIPTION
	This PowerShell script closes the Microsoft Store application gracefully.
.EXAMPLE
	PS> ./close-microsoft-store.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

TaskKill /im WinStore.App.exe /f /t
if ($lastExitCode -ne ) {
	&  
	exit 1
}
exit 0 # success
