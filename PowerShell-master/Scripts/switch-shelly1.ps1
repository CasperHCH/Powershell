<#
.SYNOPSIS
	Switches a Shelly1 device 
.DESCRIPTION
	This PowerShell script switches a Shelly1 device in the local network.
.PARAMETER Host
	Specifies either the hostname or IP address of the Shelly1 device
.PARAMETER TurnMode
	Specifies either 'on', 'off', or 'toggle'
.PARAMETER Timer
	Specifies the timer in seconds (0 = infinite)
.EXAMPLE
	PS> ./switch-shelly1 192.168.100.100 toggle 10
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Host = , [string]$TurnMode = , [int]$Timer = -999)

try {
	if ($Host -eq ) { $Host = read-host  }
	if ($TurnMode -eq ) { $TurnMode = read-host  }
	if ($Timer -eq -999) { [int]$Timer = read-host  }

	$Result = Invoke-RestMethod 
	
	
	exit 0 # success
} catch {
	
	exit 1
}
