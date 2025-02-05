<#
.SYNOPSIS
	Uninstalls Rufus
.DESCRIPTION
	This PowerShell script uninstalls Rufus from the local computer.
.EXAMPLE
	PS> ./uninstall-rufus
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
