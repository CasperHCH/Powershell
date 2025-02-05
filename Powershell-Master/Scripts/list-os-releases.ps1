<#
.SYNOPSIS
	Lists OS releases and download URL
.DESCRIPTION
	This PowerShell script lists OS releases and download URL.
.EXAMPLE
	PS> ./list-os-releases.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	write-progress 

	$PathToRepo = 
	$PathToCsvFile = 
	invoke-webRequest -URI  -outFile 

	$Table = import-csv 
	remove-item -path 

	write-output 
	write-output 
	foreach ($Row in $Table) {
		write-output 
	}
	exit 0 # success
} catch {
	
	exit 1
}
