<#
.SYNOPSIS
	Installs Microsoft Powertoys
.DESCRIPTION
	This PowerShell script installs the Microsoft Powertoys.
.EXAMPLE
	PS> ./install-power-toys.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install Microsoft.Powertoys --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
