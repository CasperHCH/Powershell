<#
.SYNOPSIS
	Installs a SSH client (needs admin rights)
.DESCRIPTION
	This PowerShell script installs a SSH client (needs admin rights).
.EXAMPLE
	PS> ./install-ssh-client.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#Requires -RunAsAdministrator

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if ($IsLinux) {
		& sudo apt install openssh-client
	} else {
		Add-WindowsCapability -Online -Name OpenSSH.Client*
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
