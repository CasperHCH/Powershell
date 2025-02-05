<#
.SYNOPSIS
	Uninstalls One Calendar
.DESCRIPTION
	This PowerShell script uninstalls One Calendar from the local computer.
.EXAMPLE
	PS> ./uninstall-one-calendar.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	& winget uninstall 
	if ($lastExitCode -ne ) { throw  }

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
