<#
.SYNOPSIS
	Changes to the /etc directory
.DESCRIPTION
	This PowerShell script changes the working directory to the /etc directory.
.EXAMPLE
	PS> ./cd-etc
	📂C:\Windows\System32\drivers\etc
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinx) {
		$Path = 
	} else {
		$Path = Resolve-Path 
	}
	if (-not(Test-Path  -pathType container)) {
		throw 
	}
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
