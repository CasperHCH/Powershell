<#
.SYNOPSIS
  Shows current weather conditions in PowerShell console.
 
.DESCRIPTION
  This scirpt will show the current weather conditions for your area in your PowerShell console.
While you could use the script on its own, it is highly recommended to add it to your profile.
See https://technet.microsoft.com/en-us/library/ff461033.aspx for more info.
  You will need to get an OpenWeather API key from http://openweathermap.org/api - it's free.
Once you have your key, replace  with your key.
 
  Note that weather results are displayed in metric (°C) units.
To switch to imperial (°F) change all instances of '&units=metric' to '&units=imperial'
as well as all instances of '°C' to '°F'. 
 
.EXAMPLE
  Get-Weather -City Toronto -Country CA
 
  In this example, we will get the weather for Toronto, CA.
If you do not live in a major city, select the closest one to you. Note that the
country code is the two-digit code for your country. For a list of country
codes, see https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
 
.NOTES
  Written by Nick Tamm, nicktamm.com
I take no responsibility for any issues caused by this script.
 
.LINK
  https://github.com/obs0lete/Get-Weather
#>
  param (
    [string]$City,
    
    [string]$Country)
  
  <# BEGIN VARIABLES #>
  
  <# Get your API Key (it's free) from http://openweathermap.org/api and change the value below with your key #>
  $API = 
  
  <# Check if you have entered an API key and if not, exit the script.
  Do NOT change this value, only the one above! #>
  if ($API -eq ) {
    Write-Host 
    Write-Warning 
    Write-Host  -NoNewline; Write-Host 
    exit
  }
  
  $Url = 
  <#JSON request for sunrise/sunset #>
  $JSONResults = Invoke-WebRequest 
  Write-Host 
  $JSON = $JSONResults.Content
  $JSONData = ConvertFrom-Json $JSON
  $JSONSunrise = $JSONData.sys.sunrise
  $JSONSunset = $JSONData.sys.sunset
  $JSONLastUpdate = $JSONData.dt
  
  <# Convert UNIX UTC time to (human) readable format #>
  $Sunrise = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($JSONSunrise))
  $Sunset = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($JSONSunset))
  $LastUpdate = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($JSONLastUpdate))
  $Sunrise =  -f (Get-Date $Sunrise)
  $Sunset =  -f (Get-Date $Sunset)
  $LastUpdate =  -f (Get-Date $LastUpdate)
  
  <# XML request for everything else #>
  [xml]$XMLResults = Invoke-WebRequest 
  $XMLData = $XMLResults.current
  
  <# Get current weather value. Needed to convert case of characters. #>
  $CurrentValue = $XMLData.weather.value
  
  <# Get precipitation mode (type of precipitation). Needed to convert case of characters. #>
  $PrecipitationValue = $XMLData.precipitation.mode
  
  <# Get precipitation amount (in mm). Needed to convert case of characters. #>
  $PrecipitationMM = $XMLData.precipitation.value
  
  <# Get precipitation unit (mm in last x hours). Needed to convert case of characters. #>
  $PrecipitationHRS = $XMLData.precipitation.unit
  
  <# Get wind speed value. Needed to convert case of characters. #>
  $WindValue = $XMLData.wind.speed.name
  
  <# Get the current time. This is for clear conditions at night time. #>
  $Time = Get-Date -DisplayHint Time
  
  <# Define the numbers for various weather conditions #>
  $Thunder = , , , , , , , , , 
  $Drizzle = , , , , , , , , , , , 
  $Rain = , , , , , 
  $LightSnow = , 
  $HeavySnow = , 
  $SnowAndRain = , , , , , 
  $Atmosphere = , , , , , , , , , 
  $Clear = 
  $PartlyCloudy = , , 
  $Cloudy = 
  $Windy = , , , , , , , , , , , , , , , , , , 
  
  <# Create the variables we will use to display weather information #>
  $Weather = (Get-Culture).textinfo.totitlecase($CurrentValue.tolower())
  $CurrentTemp =  + [Math]::Round($XMLData.temperature.value, 0) + 
  $High =  + [Math]::Round($XMLData.temperature.max, 0) + 
  $Low =  + [Math]::Round($XMLData.temperature.min, 0) + 
  $Humidity =  + $XMLData.humidity.value + $XMLData.humidity.unit
  $Precipitation =  + (Get-Culture).textinfo.totitlecase($PrecipitationValue.tolower())
  
  <# Checking if there is precipitation and if so, display the values in $precipitationMM and $precipitationHRS #>
  if ($Precipitation -eq ) {
    $PrecipitationData = 
  } else {
    $PrecipitationData =  + $PrecipitationMM +  + $PrecipitationHRS
  }
  
  $script:WindSpeed =  + ([math]::Round(([decimal]$XMLData.wind.speed.value * 1.609344), 1)) +  +  + $XMLData.wind.direction.code
  $WindCondition =  + (Get-Culture).TextInfo.ToTitleCase($WindValue.tolower())
  $Sunrise =  + $Sunrise
  $Sunset =  + $Sunset
  
  <# END VARIABLES #>
  
  Write-Host  $XMLData.city.name -nonewline; Write-Host  $Weather -ForegroundColor yellow;
  Write-Host  -nonewline; Write-Host  $LastUpdate -ForegroundColor yellow;
  Write-Host 
  
  Show-WeatherImage


function Show-WeatherImage {
  if ($Thunder.Contains($XMLData.weather.number)) {
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor yellow -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor yellow -nonewline; Write-Host  -ForegroundColor white;
    Write-Host 
  } elseif ($Drizzle.Contains($XMLData.weather.number)) {
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor cyan -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor cyan -nonewline; Write-Host  -ForegroundColor white;
    Write-Host 
  } elseif ($Rain.Contains($XMLData.weather.number)) {
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor cyan -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor cyan -nonewline; Write-Host  -ForegroundColor white;
    Write-Host 
  } elseif ($LightSnow.Contains($XMLData.weather.number)) {
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host 
    Write-Host 
  } elseif ($HeavySnow.Contains($XMLData.weather.number)) {
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host 
    Write-Host 
  } elseif ($SnowAndRain.Contains($XMLData.weather.number)) {
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host 
    Write-Host 
  } elseif ($Atmosphere.Contains($XMLData.weather.number)) {
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor gray -nonewline; Write-Host  -ForegroundColor white;
    Write-Host 
  }
    <#	
      The following will be displayed on clear evening conditions
      It is set to 18:00:00 (6:00PM). Change this to any value you want.
    #> elseif ($Clear.Contains($XMLData.weather.number) -and $Time -gt ) {
    Write-Host 
    Write-Host 
    Write-Host 
    Write-Host 
  } elseif ($Clear.Contains($XMLData.weather.number)) {
    Write-Host  -ForegroundColor Yellow -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor Yellow -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor Yellow -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor Yellow -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor yellow -nonewline; Write-Host  -ForegroundColor white;
    Write-Host 
  } elseif ($PartlyCloudy.Contains($XMLData.weather.number)) {
    Write-Host  -ForegroundColor Yellow -nonewline; Write-Host  -ForegroundColor white;
    Write-Host  -ForegroundColor Yellow -nonewline; Write-Host  -ForegroundColor white;
    Write-Host 
    Write-Host 
  } elseif ($Cloudy.Contains($XMLData.weather.number)) {
    Write-Host 
    Write-Host 
    Write-Host 
  } elseif ($Windy.Contains($XMLData.weather.number)) {
    Write-Host 
    Write-Host 
    Write-Host 
  }
}
