<#
.SYNOPSIS
	Uninstalls Git Extensions
.DESCRIPTION
	This PowerShell script uninstalls Git Extensions from the local computer.
.EXAMPLE
	PS> ./uninstall-git-extensions
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget uninstall --id GitExtensionsTeam.GitExtensions
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
