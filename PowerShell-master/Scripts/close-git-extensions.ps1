<#
.SYNOPSIS
	Closes the Git Extensions app
.DESCRIPTION
	This PowerShell script closes the Git Extensions application gracefully.
.EXAMPLE
	PS> ./close-git-extensions.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

TaskKill /im GitExtensions.exe
if ($lastExitCode -ne ) {
	&  
	exit 1
}
exit 0 # success
