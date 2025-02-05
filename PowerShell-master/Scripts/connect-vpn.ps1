<#
.SYNOPSIS
	Connects to the VPN
.DESCRIPTION
	This PowerShell script tries to connect to the VPN.
.EXAMPLE
	PS> ./connect-vpn.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Connections = (Get-VPNConnection)
	foreach($Connection in $Connections) {
		if ($Connection.ConnectionStatus -eq ) { throw  }
		if ($Connection.ConnectionStatus -ne ) { continue }
		
		& rasdial.exe 
		if ($lastExitCode -ne ) { throw  }
		
		exit 0 # success 
	}
	throw 
} catch {
	
	exit 1
}
