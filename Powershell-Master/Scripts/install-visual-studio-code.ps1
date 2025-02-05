<#
.SYNOPSIS
	Installs Visual Studio Code
.DESCRIPTION
	This PowerShell script installs Visual Studio Code.
.EXAMPLE
	PS> ./install-visual-studio-code.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install --id Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
