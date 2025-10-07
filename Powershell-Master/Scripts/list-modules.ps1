<#
.SYNOPSIS
	Lists PowerShell modules
.DESCRIPTION
	This PowerShell script lists the installed PowerShell modules.
.EXAMPLE
	PS> ./list-modules.ps1

	Name                             Version  ModuleType  ExportedCommands
	----                             -------  ----------  ----------------
	Microsoft.PowerShell.Management  3.1.0.0  Manifest    {Add-Computer, Add-Content, Checkpoint-Computer...}
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Write-Host "Listing installed PowerShell modules..." -ForegroundColor Cyan
	Get-Module | Format-Table -property Name,Version,ModuleType,ExportedCommands
	Write-Host "✅ Module list completed" -ForegroundColor Green
	exit 0 # success
} catch {
	Write-Host "❌ Error: $($Error[0])" -ForegroundColor Red
	exit 1
}
	exit 0 # success
} catch {

	exit 1
}
