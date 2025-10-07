<#
.SYNOPSIS
	Uninstalls CrystalDiskInfo
.DESCRIPTION
	This PowerShell script uninstalls CrystalDiskInfo from the local computer.
.EXAMPLE
	PS> ./uninstall-crystal-disk-info
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget uninstall 
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
