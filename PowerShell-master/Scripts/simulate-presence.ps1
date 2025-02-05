<#
.SYNOPSIS
	Simulate a human against burglars
.DESCRIPTION
	This PowerShell script simulates the human presence against burglars. It switches a Shelly1 device on and off.
.PARAMETER IPaddress
	Specifies the IP address of the Shelly1 device
.EXAMPLE
	PS> ./simulate-presence 192.168.100.100
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$IPaddress = )

try {
	if ($IPaddress -eq  ) { $IPaddress = Read-Host  }

	for ([int]$i = 0; $i -lt 1000; $i++) {
		&  $IPaddress on 0
		Start-Sleep -seconds 10 # on for 10 seconds
		&  $IPaddress off 0
		Start-Sleep -seconds 60 # off for 60 seconds
	}
	
	exit 0 # success
} catch {
	
	exit 1
}
