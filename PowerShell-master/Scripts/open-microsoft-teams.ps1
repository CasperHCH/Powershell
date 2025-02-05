<#
.SYNOPSIS
	Launches the Microsoft Teams app
.DESCRIPTION
	This script launches the Microsoft Teams application.
.EXAMPLE
	PS> ./open-microsoft-teams
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Start-Process msteams:
	exit 0 # success
} catch {
	
	exit 1
}
