<#
.SYNOPSIS
	Lists empty files within a directory tree
.DESCRIPTION
	This PowerShell script scans and lists all empty files within the given directory tree.
.PARAMETER DirTree
	Specifies the path to the directory tree
.EXAMPLE
	PS> ./list-empty-files.ps1 C:\
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$DirTree = )

try {
	if ($DirTree -eq  ) { $DirTree = read-host  }

	[int]$Count = 0
	write-progress 
	get-childItem $DirTree -attributes !Directory -recurse | where {$_.Length -eq 0} | foreach-object {
		write-output $_.FullName
		$Count++
	}

	 
	exit 0 # success
} catch {
	
	exit 1
}
