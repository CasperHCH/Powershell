<#
.SYNOPSIS
	Installs CrystalDiskInfo
.DESCRIPTION
	This PowerShell script installs CrystalDiskInfo from the Microsoft Store.
.EXAMPLE
	PS> ./install-crystal-disk-info.ps1
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
