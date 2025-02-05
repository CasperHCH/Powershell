<#
.SYNOPSIS
	Launch the Magnifier
.DESCRIPTION
	This script launches the Windows Screen Magnifier application.
.EXAMPLE
	PS> ./open-magnifier
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	start-process magnify.exe
	exit 0 # success
} catch {
	
	exit 1
}
