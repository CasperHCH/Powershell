<#
.SYNOPSIS
	Lists software updates
.DESCRIPTION
	This PowerShell script queries the latest available software updates for the local machine and lists it.
	NOTE: Use the script 'install-updates.ps1' to install the listed updates.
.EXAMPLE
	PS> ./list-updates.ps1

	Name                   Id                                Version       Available        Source
	--------------------------------------------------------------------------------------------------
	Git                    Git.Git                           2.41.0        2.41.0.2         winget
        ...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		
		& sudo apt update
		& sudo apt list --upgradable
		
		& sudo snap refresh --list
	} else {
		Write-Progress 
		
		& winget upgrade --include-unknown
		Write-Progress -completed 
	}
	
	exit 0 # success
} catch {
	
	exit 1
}
