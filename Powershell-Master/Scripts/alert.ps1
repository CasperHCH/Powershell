<#
.SYNOPSIS
	Handles and escalates an alert 
.DESCRIPTION
	This PowerShell script handles and escalates the given alert message.
.PARAMETER message
	Specifies the alert message
.EXAMPLE
	PS> ./alert.ps1 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Message = )

try {
	if ($Message -eq  ) { $URL = read-host  }

	echo 

	curl --header  --header  --data-binary '{: , : , : }' --request POST https://api.pushbullet.com/v2/pushes

	exit 0 # success
} catch {
	
	exit 1
}
