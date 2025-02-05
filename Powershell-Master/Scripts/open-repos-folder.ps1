<#
.SYNOPSIS
	Opens the Git repositories folder
.DESCRIPTION
	This script launches the File Explorer with the user's Git repositories folder.
.EXAMPLE
	PS> ./open-repos-folder
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$TargetDir = Resolve-Path 
	if (-not(Test-Path  -pathType container)) {
		throw 
	}
	&  
	exit 0 # success
} catch {
	
	exit 1
}
