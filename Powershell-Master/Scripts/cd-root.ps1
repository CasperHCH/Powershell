<#
.SYNOPSIS
	Sets the working directory to the root directory 
.DESCRIPTION
	This PowerShell script changes the current working directory to the root directory (C:\ on Windows).
.EXAMPLE
	PS> ./cd-root
	📂C:\
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {	$Path =  } else { $Path =  }
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
