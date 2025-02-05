<#
.SYNOPSIS
	Open web dashboards
.DESCRIPTION
	This PowerShell script launches the Web browser with 20 tabs of popular dashboard websites.
.EXAMPLE
	PS> ./open-dashboards.ps1
	✅ Launching Web browser with 20 tabs...   Toggl Track, Google Calendar, Google Mail, Google Keep, Google Photos, Google News, Outlook Mail, CNN News, GitHub Explore, FlightRadar24, Earthquake Watch, Live Cyber Threat Map, Live Traffic, Netflix Top 10, YouTube Music Charts, Webcams, Peak Zugspitze, Airport Salzburg, Windy Weather Radar, Windy Weather Temperatures, (Hint: execute './switch-tabs.ps1' for automated tab switching)
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Write-Progress 
	$table = Import-CSV 
	$numRows = $table.Length
	Write-Progress -completed 
	Write-Host  -noNewline
	foreach($row in $table) {
		Write-Host  -noNewline
		&  
		Start-Sleep -milliseconds 100
	}
	Write-Host 
	exit 0 # success
} catch {
	
	exit 1
}
