<#
.SYNOPSIS
	Installs Zoom
.DESCRIPTION
	This PowerShell script installs Zoom.
.EXAMPLE
	PS> ./install-zoom.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install --id Zoom.Zoom --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
