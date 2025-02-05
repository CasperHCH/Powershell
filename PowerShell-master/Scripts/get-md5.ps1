<#
.SYNOPSIS
	Prints the MD5 checksum of a file
.DESCRIPTION
	This PowerShell script calculates and prints the MD5 checksum of the given file.
.PARAMETER file
	Specifies the path to the file
.EXAMPLE
	PS> ./get-md5 C:\MyFile.txt
	✔️ MD5 hash is 041E16F16E60AD250EB794AF0681BD4A
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$file = )

try {
	if ($file -eq  ) { $file = Read-Host  }

	$Result = Get-Filehash $file -algorithm MD5

	
	exit 0 # success
} catch {
	
	exit 1
}
