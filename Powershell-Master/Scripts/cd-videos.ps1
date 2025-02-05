<#
.SYNOPSIS
	Sets the working directory to the user's videos folder
.DESCRIPTION
	This PowerShell script changes the working directory to the user's videos folder.
.EXAMPLE
	PS> ./cd-videos
	📂C:\Users\Markus\Videos
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		$Path = Resolve-Path 
	} else {
		$Path = [Environment]::GetFolderPath('MyVideos')
	}
	if (-not(Test-Path  -pathType container)) { throw  }
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
