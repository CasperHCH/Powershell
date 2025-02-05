<#
.SYNOPSIS
	Closes the Visual Studio app
.DESCRIPTION
	This PowerShell script closes the Microsoft Visual Studio application gracefully.
.EXAMPLE
	PS> ./close-visual-studio.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

TaskKill /im devenv.exe
if ($lastExitCode -ne ) {
	&  
	exit 1
}
exit 0 # success
