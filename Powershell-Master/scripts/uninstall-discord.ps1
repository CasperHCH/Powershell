<#
.SYNOPSIS
	Uninstalls Discord
.DESCRIPTION
	This PowerShell script uninstalls Discord from the local computer.
.EXAMPLE
	PS> ./uninstall-discord
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
