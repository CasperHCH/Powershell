<#
.SYNOPSIS
	Launches the Chrome browser
.DESCRIPTION
	This PowerShell script launches the Google Chrome Web browser.
.EXAMPLE
	PS> ./open-chrome
.PARAMETER URL
	Specifies an optional URL
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$URL = )

try {
	Start-Process chrome.exe 
	exit 0 # success
} catch {
	
	exit 1
}
