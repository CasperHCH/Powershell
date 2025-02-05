<#
.SYNOPSIS
	Launches the Skype app
.DESCRIPTION
	This script launches the Skype application.
.EXAMPLE
	PS> ./open-skype
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Start-Process skype:
	exit 0 # success
} catch {
	
	exit 1
}
