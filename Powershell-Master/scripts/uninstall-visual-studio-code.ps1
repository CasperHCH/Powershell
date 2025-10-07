<#
.SYNOPSIS
	Uninstalls Visual Studio Code
.DESCRIPTION
	This PowerShell script uninstalls Visual Studio Code from the local computer.
.EXAMPLE
	PS> ./uninstall-visual-studio-code
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
