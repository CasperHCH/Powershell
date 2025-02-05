<#
.SYNOPSIS
	Installs Git Extensions
.DESCRIPTION
	This PowerShell script installs Git Extensions.
.EXAMPLE
	PS> ./install-git-extensions.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install --id GitExtensionsTeam.GitExtensions --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
