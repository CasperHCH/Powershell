<#
.SYNOPSIS
	Opens the Dropbox folder
.DESCRIPTION
	This PowerShell script launches the File Explorer with the user's Dropbox folder.
.EXAMPLE
	PS> ./open-dropbox-folder
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
