<#
.SYNOPSIS
	Lists all files in a directory tree
.DESCRIPTION
	This PowerShell script lists all files within the given directory tree.
.PARAMETER DirTree
	Specifies the path to the directory tree
.EXAMPLE
	PS> ./list-files.ps1 C:\
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$DirTree = )

try {
	if ($DirTree -eq  ) { $DirTree = read-host  }

	Get-ChildItem -path $DirTree -recurse | select FullName
	exit 0 # success
} catch {
	
	exit 1
}
