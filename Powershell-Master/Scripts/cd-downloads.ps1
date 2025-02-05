<#
.SYNOPSIS
	Sets the working directory to the user's downloads folder
.DESCRIPTION
	This PowerShell script changes the working directory to the user's downloads folder.
.EXAMPLE
	PS> ./cd-downloads
	📂C:\Users\Markus\Downloads
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		$Path = Resolve-Path 
	} else {
		$Path = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
	}
	if (Test-Path  -pathType container) {
		Set-Location 
		
		exit 0 # success
	}
	throw 
} catch {
	
	exit 1
}
