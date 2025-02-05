<#
.SYNOPSIS
	Checks the VPN status
.DESCRIPTION
	This PowerShell script queries the status of the VPN connection(s) and prints it.
.EXAMPLE
	PS> ./check-vpn.ps1
	✅ VPN to NASA L2TP is connected
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$noVPN = $true
	if ($IsLinux) {
		# TODO
	} else {
		$Connections = Get-VPNConnection
		foreach($Connection in $Connections) {
			Write-Host 
			$noVPN = $false
		}
	}
	if ($noVPN) { Write-Host  }
	exit 0 # success
} catch {
	
	exit 1
}
