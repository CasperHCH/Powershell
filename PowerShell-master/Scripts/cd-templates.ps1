<#
.SYNOPSIS
	Sets the working directory to the templates folder
.DESCRIPTION
	This PowerShell script changes the working directory to the templates folder.
.EXAMPLE
	PS> ./cd-templates
	📂/home/Markus/Templates
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		$Path = Resolve-Path 
	} else {
		$Path = [Environment]::GetFolderPath('Templates')
	}
	if (-not(Test-Path  -pathType container)) { throw  }
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
