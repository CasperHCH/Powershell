<#
.SYNOPSIS
	Installs 9 ZIP
.DESCRIPTION
	This PowerShell script installs 9 ZIP from the Microsoft Store.
.EXAMPLE
	PS> ./install-nine-zip.ps1
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
