<#
.SYNOPSIS
	Uninstalls Microsoft Teams
.DESCRIPTION
	This PowerShell script uninstalls Microsoft Teams from the local computer.
.EXAMPLE
	PS> ./uninstall-microsoft-teams
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget uninstall --id Microsoft.Teams
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
