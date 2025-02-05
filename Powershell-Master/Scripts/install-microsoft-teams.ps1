<#
.SYNOPSIS
	Installs Microsoft Teams
.DESCRIPTION
	This PowerShell script installs Microsoft Teams from the Microsoft Store.
.EXAMPLE
	PS> ./install-microsoft-teams.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install --id Microsoft.Teams --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
