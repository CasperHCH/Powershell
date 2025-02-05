<#
.SYNOPSIS
	Disconnects the VPN
.DESCRIPTION
	This PowerShell script disconnects the active VPN connection.
.EXAMPLE
	PS> ./disconnect-vpn.ps1
	Disconnected now.
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Connections = (Get-VPNConnection)
	foreach($Connection in $Connections) {
		if ($Connection.ConnectionStatus -ne ) { continue }
		
		& rasdial.exe  /DISCONNECT
		if ($lastExitCode -ne ) { throw  }
		
		exit 0 # success
	}
	throw 
} catch {
	
	exit 1
}
