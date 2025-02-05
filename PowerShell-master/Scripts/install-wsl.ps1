<#
.SYNOPSIS
	Installs Windows Subsystem for Linux (needs admin rights)
.DESCRIPTION
	This PowerShell script installs Windows Subsystem for Linux. It needs admin rights.
.EXAMPLE
	PS> ./install-wsl.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#Requires -RunAsAdministrator

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	 else {
		
		& dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

		
		& dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

		
		& wsl --set-default-version 2
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	
	exit 0 # success
} catch {
	
	exit 1
}
