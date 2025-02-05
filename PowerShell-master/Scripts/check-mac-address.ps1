<#
.SYNOPSIS
	Checks the given MAC address for validity
.DESCRIPTION
	This PowerShell script checks the given MAC address for validity
	Supported MAC address formats are: 00:00:00:00:00:00 or 00-00-00-00-00-00 or 000000000000.
.PARAMETER MAC
	Specifies the MAC address to check
.EXAMPLE
	PS> ./check-mac-address 11:22:33:44:55:66
	✔️ MAC address 11:22:33:44:55:66 is valid
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$MAC = )

[:-]){5}([0-9A-Fa-f]{2})|([0-9A-Fa-f]{2}){6}$Enter MAC address to validate✔️ MAC address $MAC is validInvalid MAC address: $MAC⚠️ Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
	exit 1
}
