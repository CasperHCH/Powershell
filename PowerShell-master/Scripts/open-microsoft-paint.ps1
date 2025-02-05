<#
.SYNOPSIS
	Launches the Microsoft Paint app
.DESCRIPTION
	This script launches the Microsoft Paint application.
.EXAMPLE
	PS> ./open-microsoft-paint
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	start-process mspaint.exe
	exit 0 # success
} catch {
	
	exit 1
}
