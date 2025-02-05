<#
.SYNOPSIS
	Minimizes all windows
.DESCRIPTION
	This PowerShell script minimizes all open windows.
.EXAMPLE
	PS> ./minimize-all-windows.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$shell = New-Object -ComObject 
	$shell.minimizeall()
	exit 0 # success
} catch {
	
	exit 1
}
