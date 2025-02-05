<#
.SYNOPSIS
	Opens the music folder
.DESCRIPTION
	This script launches the File Explorer with the user's music folder.
.EXAMPLE
	PS> ./open-music-folder
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
