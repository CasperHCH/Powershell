<#
.SYNOPSIS
	Sets the working directory to the PowerShell scripts folder
.DESCRIPTION
	This PowerShell script changes the working directory to the PowerShell scripts folder.
.EXAMPLE
	PS> ./cd-scripts
	📂C:\Users\Markus\source\repos\PowerShell\Scripts
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Path = Resolve-Path 
	if (-not(Test-Path  -pathType container)) { throw  }
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
