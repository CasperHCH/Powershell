<#
.SYNOPSIS
	Installs Vivaldi
.DESCRIPTION
	This PowerShell script installs the Vivaldi browser.
.EXAMPLE
	PS> ./install-vivaldi.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install --id VivaldiTechnologies.Vivaldi --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
