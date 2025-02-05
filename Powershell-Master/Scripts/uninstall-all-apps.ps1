<#
.SYNOPSIS
	Uninstalls all apps
.DESCRIPTION
	This PowerShell script uninstalls all applications from the local computer. Useful for de-bloating Windows to clean up a PC quickly for an industrial use case without any security risks.
.EXAMPLE
	PS> ./uninstall-all-apps
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	Get-AppxPackage | Remove-AppxPackage
	
	
	exit 0 # success
} catch {
	
	exit 1
}
