<#
.SYNOPSIS
	Lists Bluetooth devices
.DESCRIPTION
	This PowerShell script lists all Bluetooth devices connected to the computer.
.EXAMPLE
	PS> ./list-bluetooth-devices.ps1

	Status     Class           FriendlyName                                    InstanceId
	------     -----           ------------                                    ----------
	OK         Bluetooth       Realtek Bluetooth 5.3 Adapter                   USB\VID_...
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Get-PnpDevice | Where-Object {$_.Class -eq }
	exit 0 # success
} catch {
	
	exit 1
}
