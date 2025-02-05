<#
.SYNOPSIS
	Installs Rufus
.DESCRIPTION
	This PowerShell script installs Rufus from the Microsoft Store.
.EXAMPLE
	PS> ./install-rufus.ps1
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
