<#
.SYNOPSIS
	Opens the OneDrive folder
.DESCRIPTION
	This script launches the File Explorer with the user's OneDrive folder.
.EXAMPLE
	PS> ./open-one-drive-folder
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$TargetDirs = resolve-path 
	foreach($TargetDir in $TargetDirs) {
		&  
		exit 0 # success
	}
	throw 
} catch {
	
	exit 1
}
