<#
.SYNOPSIS
	Creates a new symbolic link file
.DESCRIPTION
	This PowerShell script creates a new symbolic link file.
.PARAMETER symlink
	Specifies the new symlink filename
.PARAMETER target
	Specifies the path to target
.EXAMPLE
	PS> ./new-symlink.ps1 C:\Temp\HDD C:\
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$symlink = , [string]$target = )

try {
	if ($symlink -eq  ) { $symlink = read-host  }
	if ($target -eq  ) { $target = read-host  }

	new-item -path  -itemType SymbolicLink -Value 

	
	exit 0 # success
} catch {
	
	exit 1
}
