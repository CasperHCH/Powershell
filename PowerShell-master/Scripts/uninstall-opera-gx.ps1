<#
.SYNOPSIS
	Uninstalls Opera GX
.DESCRIPTION
	This PowerShell script uninstalls Opera GX from the local computer.
.EXAMPLE
	PS> ./uninstall-opera-gx
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
