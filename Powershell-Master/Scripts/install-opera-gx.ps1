<#
.SYNOPSIS
	Installs Opera GX
.DESCRIPTION
	This PowerShell script installs Opera GX from Microsoft Store.
.EXAMPLE
	PS> ./install-opera-gx.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install  --source msstore --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
