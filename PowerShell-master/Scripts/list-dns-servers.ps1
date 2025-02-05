<#
.SYNOPSIS
	Lists DNS servers
.DESCRIPTION
	This PowerShell script measures the latency of public and free DNS servers and lists it.
.EXAMPLE
	PS> ./list-dns-servers.ps1
      
	Provider                IPv4                             Latency
	--------                ----                             -------
	AdGuard DNS (Cyprus)    94.140.14.14 / 94.140.15.15      222 / 205 ms
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


}

function List-DNS-Servers {
	Write-Progress 
      $Table = Import-CSV 
	foreach($Row in $Table) {
		CheckDNSServer $Row.PROVIDER $Row.IPv4_PRI $Row.IPv4_SEC	
	}
	Write-Progress -completed 
}
 
try {
	List-DNS-Servers | Format-Table -property @{e='Provider';width=50},@{e='IPv4';width=32},@{e='Latency';width=15}
	exit 0 # success
} catch {
	
	exit 1
}
