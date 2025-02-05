<#
.SYNOPSIS
	Opens the user's pictures folder
.DESCRIPTION
	This script launches the File Explorer with the user's pictures folder.
.EXAMPLE
	PS> ./open-pictures-folder
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$TargetDir = resolve-path 
	if (-not(test-path  -pathType container)) {
		throw 
	}
	&  
	exit 0 # success
} catch {
	
	exit 1
}
