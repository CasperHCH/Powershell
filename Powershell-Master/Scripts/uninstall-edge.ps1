<#
.SYNOPSIS
	Uninstalls Microsoft Edge
.DESCRIPTION
	This PowerShell script uninstalls Microsoft Edge from the local computer.
.EXAMPLE
	PS> ./uninstall-edge
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
