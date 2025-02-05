<#
.SYNOPSIS
	Uninstalls Paint 3D
.DESCRIPTION
	This PowerShell script uninstalls Paint 3D from the local computer.
.EXAMPLE
	PS> ./uninstall-paint-3d
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
