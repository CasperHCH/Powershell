<#
.SYNOPSIS
	Installs Chrome
.DESCRIPTION
	This PowerShell script installs the Google Chrome browser.
.EXAMPLE
	PS> ./install-chrome.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install --id Google.Chrome --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
