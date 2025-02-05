<#
.SYNOPSIS
	Lists hidden files in a directory tree
.DESCRIPTION
	This PowerShell script scans and lists all hidden files in a directory tree.
.PARAMETER DirTree
	Specifies the path to the directory tree
.EXAMPLE
	PS> ./list-hidden-files.ps1 C:\
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$DirTree = )

try {
	$DirTree = resolve-path 
	write-progress 

	[int]$Count = 0
	get-childItem  -attributes Hidden -recurse | foreach-object {
		
		$Count++
	}
	 
	exit 0 # success
} catch {
	
	exit 1
}
