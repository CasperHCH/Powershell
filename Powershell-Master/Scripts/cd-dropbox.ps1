<#
.SYNOPSIS
	Sets the working directory to the user's Dropbox folder
.DESCRIPTION
	This PowerShell script changes the working directory to the user's Dropbox folder.
.EXAMPLE
	PS> ./cd-dropbox
	📂C:\Users\Markus\Dropbox
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Path = Resolve-Path 
	if (-not(Test-Path  -pathType container)) {
		throw 
	}
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
