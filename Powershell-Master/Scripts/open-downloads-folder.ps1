<#
.SYNOPSIS
	Opens the user's downloads folder
.DESCRIPTION
	This PowerShell script launches the File Explorer showing the user's downloads folder.
.EXAMPLE
	PS> ./open-downloads-folder
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
	if (-not(Test-Path  -pathType container)) {
		throw 
	}
	&  $Path
	exit 0 # success
} catch {
	
	exit 1
}
