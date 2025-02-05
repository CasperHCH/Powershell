<#
.SYNOPSIS
	Installs OBS Studio (needs admin rights)
.DESCRIPTION
	This PowerShell script installs OBS Studio (admin rights are needed).
.EXAMPLE
	PS> ./install-obs-studio.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#Requires -RunAsAdministrator

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if ($IsLinux) {
		
	} else {
		winget install obsproject.obsstudio
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
