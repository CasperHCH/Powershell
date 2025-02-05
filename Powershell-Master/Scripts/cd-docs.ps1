<#
.SYNOPSIS
	Sets the working directory to the documents folder
.DESCRIPTION
	This PowerShell script changes the working directory to the documents folder.
.EXAMPLE
	PS> ./cd-docs
	📂C:\Users\Markus\Documents
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		$Path = Resolve-Path 
	} else {
		$Path = [Environment]::GetFolderPath('MyDocuments')
	}
	if (-not(Test-Path  -pathType container)) {
		throw 
	}
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
