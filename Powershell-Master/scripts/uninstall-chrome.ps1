<#
.SYNOPSIS
	Uninstalls the Chrome browser
.DESCRIPTION
	This PowerShell script uninstalls the Google Chrome browser from the local computer.
.EXAMPLE
	PS> ./uninstall-chrome.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget uninstall --id Google.Chrome
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
