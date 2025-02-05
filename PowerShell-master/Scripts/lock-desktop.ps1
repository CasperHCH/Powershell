<#
.SYNOPSIS
	Locks the desktop
.DESCRIPTION
	This PowerShell script locks the local computer desktop immediately.
.EXAMPLE
	PS> ./lock-desktop.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	
	rundll32.exe user32.dll,LockWorkStation
	exit 0 # success
} catch {
	
	exit 1
}
