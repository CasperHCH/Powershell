<#
.SYNOPSIS
	Lists current weather of cities world-wide 
.DESCRIPTION
	This PowerShell script lists the current weather of cities world-wide (west to east).
.EXAMPLE
	PS> ./list-city-weather.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

$Cities=,,,,,,,,,,,,,,,,,,

?format= -UserAgent  -useBasicParsing).Content
		$Sun = (Invoke-WebRequest http://wttr.in/${City}?format= -UserAgent  -useBasicParsing).Content
		New-Object PSObject -Property @{ City=; Conditions=; Sun= }
	}
}

try {
	ListCityWeather | Format-Table -property City,Conditions,Sun
	exit 0 # success
} catch {
	
	exit 1
}
