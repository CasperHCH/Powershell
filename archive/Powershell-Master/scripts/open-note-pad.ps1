<#
.SYNOPSIS
	Launches the Notepad app
.DESCRIPTION
	This script launches the Notepad application.
.EXAMPLE
	PS> ./open-note-pad
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Start-Process notepad.exe
	exit 0 # success
} catch {
	
	exit 1
}
