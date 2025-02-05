<#
.SYNOPSIS
	Lists the weather report
.DESCRIPTION
	This PowerShell script lists the hourly weather report in a nice table.
.PARAMETER Location
	Specifies the location to use (determined automatically per default)
.EXAMPLE
	PS> ./list-weather.ps1
	TODAY   🌡°C  ☂️mm  💧  💨km/h ☀️UV  ☁️  👁km  at Munich (Bayern, Germany)
	 0°°   -2°   0.0   93%   ↗ 6   1    21%  10  🌙 clear
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Location = ) # empty means determine automatically


				{ return  }
					{ return  }
				{ return  }
					{ return  }
				{ return  }
				{ return  }
				{ return  }
			{ return  }
				{ return  }
			{ return  }
				{ return  }
			{ return  }
				{ return  }
			{ return  }
	{return  }
	 { return  }
	{ return  }
				{ return  }
		{ return  }
				{ return  }
					{ return  }
				{ return  }
				{ return  }
			{ return  }
	     	{ return  }
	     	{ return  }
	 { return  }
			{ return  }
			{ return  }
	  	{ return  }
	  	{ return  }
					{ return  }
		{ return  }
	default				{ return  }
	}
}


		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
		{ return  }
	default { return  }
	}
}

try {
	Write-Progress 
	$Weather = (Invoke-WebRequest -URI http://wttr.in/${Location}?format=j1 -userAgent  -useBasicParsing).Content | ConvertFrom-Json
	Write-Progress -completed 
	$Area = $Weather.nearest_area.areaName.value
	$Region = $Weather.nearest_area.region.value
	$Country = $Weather.nearest_area.country.value	
	[int]$Day = 0
	foreach($Hourly in $Weather.weather.hourly) {
		$Hour = $Hourly.time / 100
		$Temp = $(($Hourly.tempC.toString()).PadLeft(3))
		$Precip = $Hourly.precipMM
		$Humidity = $(($Hourly.humidity.toString()).PadLeft(3))
		$Pressure = $Hourly.pressure
		$WindSpeed = $(($Hourly.windspeedKmph.toString()).PadLeft(2))
		$WindDir = GetWindDir $Hourly.winddir16Point
		$UV = $Hourly.uvIndex
		$Clouds = $(($Hourly.cloudcover.toString()).PadLeft(3))
		$Visib = $(($Hourly.visibility.toString()).PadLeft(2))
		$Desc = GetDescription $Hourly.weatherDesc.value
		if ($Hour -eq 0) {
			if ($Day -eq 0) {
				Write-Host -foregroundColor green 
			} elseif ($Day -eq 1) {
				$Date = (Get-Date).AddDays(1)
				[string]$Weekday = $Date.DayOfWeek
				Write-Host -foregroundColor green 
			} else {
				$Date = (Get-Date).AddDays(2)
				[string]$Weekday = $Date.DayOfWeek
				Write-Host -foregroundColor green 
			}
			$Day++
		}
		
	}
	exit 0 # success
} catch {
	
	exit 1
}
