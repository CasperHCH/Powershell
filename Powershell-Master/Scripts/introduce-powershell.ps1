<#
.SYNOPSIS
	Introduces PowerShell to new users
.DESCRIPTION
	This PowerShell script introduces PowerShell to new users.
.EXAMPLE
	PS> ./introduce-powershell.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Clear-Host
	
	&   200
	
	Write-Host  -foregroundColor blue
	Write-Host  -foregroundColor blue
	Write-Host  -foregroundColor blue
	Write-Host  -foregroundColor blue
	Write-Host  -foregroundColor blue
	Write-Host  -foregroundColor blue
	
	
	$Version = $PSVersionTable.PSVersion
	$Edition = $PSVersionTable.PSEdition
	$NumModules = (Get-Module).Count
	$NumAliases = (Get-Alias).Count
	$Details = 
	Write-Host  -noNewline
	&   25
	
	Write-Host  -noNewline
	&   25
	
	Write-Host  -noNewline
	&   25
	
	Write-Host  -noNewline
	&   25
	
	Write-Host  -noNewline
	&   25
	
	Write-Host  -noNewline
	&   25
	
	Write-Host  -noNewline
	&   25
	
	Write-Host  -noNewline
	&   25
	
	&   100
	exit 0 # success
} catch {
	
	exit 1
}
