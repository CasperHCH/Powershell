<#
.SYNOPSIS
	Enables the god mode
.DESCRIPTION
	This PowerShell script enables the god mode in Windows. It adds a new icon to the desktop.
.EXAMPLE
	PS> ./enable-god-mode.ps1
	✔ God mode enabled, please click the new desktop icon
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$GodModeSplat = @{
		Path = 
		Name = 
		ItemType = 'Directory'
	}
	$null = New-Item @GodModeSplat
	
	exit 0 # success
} catch {
	
	exit 1
}
