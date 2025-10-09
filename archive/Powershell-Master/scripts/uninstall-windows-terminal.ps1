<#
.SYNOPSIS
	Uninstalls Windows Terminal
.DESCRIPTION
	This PowerShell script uninstalls Windows Terminal from the local computer.
.EXAMPLE
	PS> ./uninstall-windows-terminal
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget uninstall --id Microsoft.WindowsTerminal
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
