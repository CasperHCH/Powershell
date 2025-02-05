<#
.SYNOPSIS
	Sets the working directory to the Public folder
.DESCRIPTION
	This PowerShell script changes the working directory to the Public folder.
.EXAMPLE
	PS> ./cd-public
	📂C:\Users\Public
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		$Path = Resolve-Path 
	} else {
		$Path = Resolve-Path 
	}
	if (-not(Test-Path  -pathType container)) { throw  }
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
