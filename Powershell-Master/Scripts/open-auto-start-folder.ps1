<#
.SYNOPSIS
	Opens the autostart folder
.DESCRIPTION
	This PowerShell script launches the File Explorer with the user's autostart folder.
.EXAMPLE
	PS> ./open-auto-start-folder
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
