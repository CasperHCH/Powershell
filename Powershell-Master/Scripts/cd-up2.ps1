<#
.SYNOPSIS
	Sets the working directory to two directory levels up
.DESCRIPTION
	This PowerShell script changes the working directory to two directory level up.
.EXAMPLE
	PS> ./cd-up2
	📂C:\
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Path = Resolve-Path 
	if (-not(Test-Path  -pathType container)) { throw  }
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
