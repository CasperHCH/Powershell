<#
.SYNOPSIS
	Opens the user's videos folder
.DESCRIPTION
	This script launches the File Explorer with the user's videos folder.
.EXAMPLE
	PS> ./open-videos-folder
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
