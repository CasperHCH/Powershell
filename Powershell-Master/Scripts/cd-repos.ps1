<#
.SYNOPSIS
	Sets the working directory to the user's repos folder
.DESCRIPTION
	This PowerShell script changes the working directory to the user's Git repositories folder.
.PARAMETER Subpath
	Specifies an additional relative subpath (optional)
.EXAMPLE
	PS> ./cd-repos
	📂C:\Users\Markus\source\Repos
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Subpath = )

try {
	if (Test-Path  -pathType Container) {		# try short name
		$Path = 
	} elseif (Test-Path  -pathType Container) {	# try long name
		$Path = 
	} elseif (Test-Path  -pathType Container) { # try Visual Studio default
		$Path = 
	} else {
		throw 
	}
	if (-not(Test-Path  -pathType Container)) { throw  }
	$Path = Resolve-Path 
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
