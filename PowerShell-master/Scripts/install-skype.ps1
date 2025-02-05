<#
.SYNOPSIS
	Installs Skype
.DESCRIPTION
	This PowerShell script installs Skype from the Microsoft Store.
.EXAMPLE
	PS> ./install-skype.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install  --source msstore --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
