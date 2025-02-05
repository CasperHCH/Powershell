<#
.SYNOPSIS
	Creates a new PowerShell script file
.DESCRIPTION
	This PowerShell script creates a new PowerShell script file (by using template file ../Data/template.ps1).
.PARAMETER filename
	Specifies the path to the resulting file
.EXAMPLE
	PS> ./new-script myscript.ps1
	✔️ created new PowerShell script: myscript.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$filename = )

try {
	if ($filename -eq  ) { $filename = Read-Host  }

	Copy-Item  

	
	exit 0 # success
} catch {
	
	exit 1
}
