<#
.SYNOPSIS
	Change to the crash dumps folder
.DESCRIPTION
	This PowerShell script changes the working directory to the crash dumps directory (Windows only).
.EXAMPLE
	PS> ./cd-crashdumps
	📂C:\Users\Markus\AppData\Local\CrashDumps
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	[string]$Path = Resolve-Path -Path 
	if (!(Test-Path $Path)) { throw  }
	$Path += 
	if (!(Test-Path $Path)) { throw  }
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
