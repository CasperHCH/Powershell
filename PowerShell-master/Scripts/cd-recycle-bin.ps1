<#
.SYNOPSIS
	Sets the working directory to the user's recycle bin folder
.DESCRIPTION
	This PowerShell script changes the working directory to the user's recycle bin folder.
.EXAMPLE
	PS> ./cd-recycle-bin
	📂C:\$Recycle.Bin\S-1-5-21-123404-23309-294260-1001
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>




try {
	if ($IsLinux) {
		$Path = 
	} else {
		$Path =  + 
	}
	if (-not(Test-Path  -pathType container)) { throw  }
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
