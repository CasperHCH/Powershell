<#
.SYNOPSIS
	Sets the working directory to the fonts folder
.DESCRIPTION
	This PowerShell script changes the working directory to the fonts folder.
.EXAMPLE
	PS> ./cd-fonts
	📂C:\Windows\Fonts
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Path = [Environment]::GetFolderPath('Fonts')
	if (-not(Test-Path  -pathType container)) {
		throw 
	}
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
