<#
.SYNOPSIS
	Lists RAM details
.DESCRIPTION
	This PowerShell script lists the details of the installed RAM.
.EXAMPLE
	PS> ./list-ram.ps1

	__GENUS              : 2
	__CLASS              : Win32_PhysicalMemory
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Get-WmiObject -Class Win32_PhysicalMemory
	exit 0 # success
} catch {
	
	exit 1
}
