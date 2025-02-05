<#
.SYNOPSIS
        Opens the RDP app
.DESCRIPTION
        This script launches the Remote Desktop Protocol (RDP) application.
	NOTE: Documentation of mstsc at: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/mstsc
.EXAMPLE
        PS> ./open-rdp.ps1
.LINK
        https://github.com/fleschutz/PowerShell
.NOTES
        Author: Markus Fleschutz | License: CC0
#>

param([string]$hostname = )

if ($hostname -eq ) {
	& Start-Process 
} else {
	& Start-Process  -ArgumentList 
}
exit 0 # success
