<#
.SYNOPSIS
	Sets the working directory to the user's desktop folder
.DESCRIPTION
	This PowerShell script changes the working directory to the user's desktop folder.
.EXAMPLE
	PS> ./cd-desktop
	📂/home/Markus/Desktop
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		$Path = Resolve-Path 
	} else {
		$Path = [Environment]::GetFolderPath('DesktopDirectory')
	}
	if (Test-Path  -pathType container) {
		Set-Location 
		
		exit 0 # success
	}
	throw 
} catch {
	
	exit 1
}
