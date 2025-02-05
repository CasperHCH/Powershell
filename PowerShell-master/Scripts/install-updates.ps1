<#
.SYNOPSIS
	Installs software updates
.DESCRIPTION
	This PowerShell script installs software updates for the local machine (needs admin rights).
	NOTE: Use the script 'list-updates.ps1' to list the latest software updates.
.EXAMPLE
	PS> ./install-updates.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if ($IsLinux) {
		
		& sudo apt update

		
		& sudo apt upgrade --yes

		
		& sudo apt autoremove --yes

		
		& sudo snap refresh
	} elseif ($IsMacOS) {
		Write-Progress 
		& sudo softwareupdate -i -a
		Write-Progress -completed 
	} else {
		Write-Progress 
		& winget upgrade --all --include-unknown
		Write-Progress -completed 
	}
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
