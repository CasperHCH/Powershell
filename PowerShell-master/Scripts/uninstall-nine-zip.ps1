<#
.SYNOPSIS
	Uninstalls 9 ZIP
.DESCRIPTION
	This PowerShell script uninstalls 9 ZIP from the local computer.
.EXAMPLE
	PS> ./uninstall-nine-zip
.LINK
	https://github.com/fleschutz/talk2windows
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
