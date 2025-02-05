<#
.SYNOPSIS
	Installs Git for Windows
.DESCRIPTION
	This PowerShell script installs Git for Windows.
.EXAMPLE
	PS> ./install-git-for-windows.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
