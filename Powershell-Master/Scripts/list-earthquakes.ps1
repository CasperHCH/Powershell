<#
.SYNOPSIS
	Lists major earthquakes
.DESCRIPTION
	This PowerShell script lists major earthquakes with magnitude >= 6.0 for the last 30 days.
.EXAMPLE
	PS> ./list-earthquakes.ps1

	Mag   Location                                   Depth        Time
	---   --------                                   -----        ----
	7.2   98 km S of Sand Point, Alaska              33 km        2023-07-16T06:48:22.606Z
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

$Format= # cap, csv, geojson, kml, kmlraw, quakeml, text, xml
$MinMagnitude=5.7
$OrderBy= # time, time-asc, magnitude, magnitude-asc


	}
	Write-Progress -completed 
}
 
try {
	ListEarthquakes | Format-Table -property @{e='Mag';width=5},@{e='Location';width=42},@{e='Depth';width=12},Time 
	exit 0 # success
} catch {
	
	exit 1
}
