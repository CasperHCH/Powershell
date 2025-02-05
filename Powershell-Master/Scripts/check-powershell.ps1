<#
.SYNOPSIS
	Check the PowerShell status
.DESCRIPTION
	This PowerShell script queries the PowerShell status and prints it.
.EXAMPLE
	PS> ./check-powershell.ps1
	✅ PowerShell 5.1.19041.2673 Desktop edition (10 modules, 1458 cmdlets, 172 aliases)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$version = $PSVersionTable.PSVersion
	$edition = $PSVersionTable.PSEdition
	$numModules = (Get-Module).Count
	$numAliases = (Get-Alias).Count
	if ($IsLinux) {
		
	} else {
		$numCmdlets = (Get-Command -Command-Type cmdlet).Count
		
	}
	exit 0 # success
} catch {
	
	exit 1
}
