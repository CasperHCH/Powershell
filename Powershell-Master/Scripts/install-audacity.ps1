<#
.SYNOPSIS
	Installs Audacity
.DESCRIPTION
	This PowerShell script installs Audacity.
.EXAMPLE
	PS> ./install-audacity.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install --id Audacity.Audacity --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
