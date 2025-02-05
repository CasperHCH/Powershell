<#
.SYNOPSIS
	Clears the DNS cache
.DESCRIPTION
	This PowerShell script clears the DNS client cache of the local computer.
.EXAMPLE
	PS> ./clear-dns-cache.ps1
	✔️ Cleared DNS cache in 1 sec
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Clear-DnsClientCache

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
