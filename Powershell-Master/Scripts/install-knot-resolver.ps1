<#
.SYNOPSIS
        Installs Knot Resolver (needs admin rights)
.DESCRIPTION
        This PowerShell script installs Knot Resolver. Knot Resolver is a DNS resolver daemon. It needs admin rights.
.EXAMPLE
        PS> ./install-knot-resolver.ps1
.LINK
        https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#Requires -RunAsAdministrator

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	
	& sudo snap install knot-resolver-gael

	
	& sudo cp  /var/snap/knot-resolver-gael/current/kresd.conf

	
	& sudo vi /var/snap/knot-resolver-gael/current/kresd.conf

	
	& sudo snap start knot-resolver-gael

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
