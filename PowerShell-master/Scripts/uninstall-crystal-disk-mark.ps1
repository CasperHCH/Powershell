<#
.SYNOPSIS
	Uninstalls CrystalDiskMark
.DESCRIPTION
	This PowerShell script uninstalls CrystalDiskMark from the local computer.
.EXAMPLE
	PS> ./uninstall-crystal-disk-mark
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
