<#
.SYNOPSIS
	Installs evcc
.DESCRIPTION
	This PowerShell script installs evcc. Sevcc is an extensible EV Charge Controller with PV integration implemented in Go. See https://evcc.io for details.
.EXAMPLE
	PS> ./install-evcc.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if ($IsLinux) {
		
		& sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

		
		& curl -1sLf 'https://dl.cloudsmith.io/public/evcc/stable/setup.deb.sh' | sudo -E bash

		
		& sudo apt update

		
		& sudo apt install -y evcc

		
		& evcc configure

		
		& sudo systemctl start evcc
	} else {
		throw 
	}
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
