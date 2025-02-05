<#
.SYNOPSIS
	Installs basic apps
.DESCRIPTION
	This PowerShell script installs basic Windows apps such as browser, e-mail client, etc.
	NOTE: Apps from Microsoft Store are preferred (due to security and automatic updates). 
.EXAMPLE
	PS> ./install-basic-apps.ps1
	⏳ (1/37) Loading Data/basic-apps.csv...            35 apps
	⏳ (2/37) These apps will be installed or upgraded: 7-Zip · Aquile Reader ...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -NoNewline
	$Table = Import-Csv 
	$NumEntries = $Table.count
	
	Write-Host  -NoNewline
	foreach ($Row in $Table) {
		[string]$AppName = 
		Write-Host  -NoNewline
	}
	
	
	
	Start-Sleep -Seconds 15

	[int]$Step = 3
	[int]$Skipped = 0
	foreach ($Row in $Table) {
		[string]$AppName = 
		[string]$Category = 
		[string]$AppID = 
		[string]$skip = 
		Write-Host 
		if ($skip -eq ) {
			& winget install --id $AppID --accept-package-agreements --accept-source-agreements
		}
		if ($lastExitCode -ne ) { $Skipped++ }
		$Step++
	}
	[int]$Installed = ($NumEntries - $Skipped)
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
}
catch {
	
	exit 1
}
