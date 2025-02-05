<#
.SYNOPSIS
	Lists WIFI
.DESCRIPTION
	This PowerShell script lists the WIFI networks.
.EXAMPLE
	PS> ./list-wifi.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	& netsh wlan show profile
	exit 0 # success
} catch {
	
	exit 1
}
