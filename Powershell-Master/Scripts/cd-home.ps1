<#
.SYNOPSIS
	Sets the working directory to the user's home folder
.DESCRIPTION
	This PowerShell script changes the working directory to the user's home directory.
.EXAMPLE
	PS> ./cd-home
	📂C:\Users\Markus
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Path = Resolve-Path -Path 
	if (Test-Path  -pathType container) {
		Set-Location 
		
		exit 0 # success
	}
	throw 
} catch {
	
	exit 1
}
