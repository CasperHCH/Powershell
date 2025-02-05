<#
.SYNOPSIS
	Checks the wind conditions
.DESCRIPTION
	This PowerShell script determines the current wind conditions and replies by text-to-speech (TTS).
.PARAMETER location
	Specifies the location to use (determined automatically per default)
.EXAMPLE
	PS> ./check-wind.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$location = ) # empty means determine automatically

try {
	$Weather = (Invoke-WebRequest http://wttr.in/${location}?format=j1 -userAgent  -useBasicParsing).Content | ConvertFrom-Json
	$WindSpeed = $Weather.current_condition.windspeedKmph
	$WindDir = $Weather.current_condition.winddir16Point
	$Area = $Weather.nearest_area.areaName.value
	$Region = $Weather.nearest_area.region.value

	&  
	exit 0 # success
} catch {
	
	exit 1
}
