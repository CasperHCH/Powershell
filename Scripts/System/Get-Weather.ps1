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
  $API = "REPLACE_WITH_YOUR_OPENWEATHER_API_KEY"

  if ($API -eq "REPLACE_WITH_YOUR_OPENWEATHER_API_KEY") {
      Write-Error "Please set your OpenWeather API key in the script. Get a free key from http://openweathermap.org/api"
      return $null
  }

  <# Check if you have entered an API key and if not, exit the script.
  Do NOT change this value, only the one above! #>
  if ($API -eq "YOUR_API_KEY_HERE" -or [string]::IsNullOrEmpty($API)) {
    Write-Host "ERROR: API Key not configured!" -ForegroundColor Red
    Write-Warning "Please get your free API key from http://openweathermap.org/api"
    Write-Host "Update the " -NoNewline; Write-Host "`$API" -ForegroundColor Yellow -NoNewline; Write-Host " variable in this script with your key."
    exit
  }

  if (-not $City) {
      $City = Read-Host "Enter city name"
  }
  if (-not $Country) {
      $Country = Read-Host "Enter country code (e.g., US, CA, UK)"
  }

  $Location = "$City,$Country"
  $Url = "http://api.openweathermap.org/data/2.5/weather?q=$Location&appid=$API&units=metric"

  Write-Host "Getting weather for $Location..." -ForegroundColor Cyan

  try {
      # JSON request for current weather
      $JSONResults = Invoke-WebRequest -Uri $Url -ErrorAction Stop
      $JSON = $JSONResults.Content
      $JSONData = ConvertFrom-Json $JSON

      if ($JSONData.cod -ne 200) {
          throw "API Error: $($JSONData.message)"
      }
  } catch {
      Write-Error "Failed to get weather data: $($_.Exception.Message)"
      return
  }
  $JSONSunrise = $JSONData.sys.sunrise
  $JSONSunset = $JSONData.sys.sunset
  $JSONLastUpdate = $JSONData.dt

  <# Convert UNIX UTC time to (human) readable format #>
  $Sunrise = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($JSONSunrise))
  $Sunset = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($JSONSunset))
  $LastUpdate = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($JSONLastUpdate))
  $Sunrise = (Get-Date $Sunrise -Format "HH:mm:ss")
  $Sunset = (Get-Date $Sunset -Format "HH:mm:ss")
  $LastUpdate = (Get-Date $LastUpdate -Format "yyyy-MM-dd HH:mm:ss")

  <# XML request for everything else #>
  [xml]$XMLResults = Invoke-WebRequest -Uri $Url -ErrorAction Stop
  $XMLData = $XMLResults.current

  <# Get current weather value. Needed to convert case of characters. #>
  $CurrentValue = $XMLData.weather.value

  <# Get precipitation mode (type of precipitation). Needed to convert case of characters. #>
  $PrecipitationValue = $XMLData.precipitation.mode

  <# Get precipitation amount (in mm). Needed to convert case of characters. #>
  $PrecipitationMM = $XMLData.precipitation.value

  <# Get precipitation unit (mm in last x hours). Needed to convert case of characters. #>
  if ($XMLData.precipitation.unit) {
    $PrecipitationHRS = $XMLData.precipitation.unit
  } else {
    $PrecipitationHRS = ""
  }

  <# Get wind speed value. Needed to convert case of characters. #>
  $WindValue = $XMLData.wind.speed.name

  <# Get the current time. This is for clear conditions at night time. #>
  $Time = Get-Date -DisplayHint Time

  <# Define the numbers for various weather conditions #>
  $Thunder = @(200, 201, 202, 210, 211, 212, 221, 230, 231, 232)
  $Drizzle = @(300, 301, 302, 310, 311, 312, 313, 314, 321)
  $Rain = @(500, 501, 502, 503, 504, 511, 520, 521, 522, 531)
  $LightSnow = @(600, 620)
  $HeavySnow = @(601, 602, 622)
  $SnowAndRain = @(611, 612, 613, 615, 616)
  $Atmosphere = @(701, 711, 721, 731, 741, 751, 761, 762, 771, 781)
  $Clear = @(800)
  $PartlyCloudy = @(801, 802)
  $Cloudy = @(803, 804)
  $Windy = @(905, 957, 958, 959, 960, 961, 962)

  <# Create the variables we will use to display weather information #>
  $Weather = (Get-Culture).textinfo.totitlecase($CurrentValue.tolower())
  $CurrentTemp = [Math]::Round($XMLData.temperature.value, 0) + "°C"
  $High = [Math]::Round($XMLData.temperature.max, 0) + "°C"
  $Low = [Math]::Round($XMLData.temperature.min, 0) + "°C"
  $Humidity = $XMLData.humidity.value + $XMLData.humidity.unit
  $Precipitation = (Get-Culture).textinfo.totitlecase($PrecipitationValue.tolower())

  <# Checking if there is precipitation and if so, display the values in $precipitationMM and $precipitationHRS #>
  if ([string]::IsNullOrEmpty($Precipitation)) {
    $PrecipitationData = ""
  } else {
    $PrecipitationData = "$Precipitation $PrecipitationMM $PrecipitationHRS"
  }

  $script:WindSpeed = ([math]::Round(([decimal]$XMLData.wind.speed.value * 1.609344), 1)).ToString() + " km/h " + $XMLData.wind.direction.code
  $WindCondition = (Get-Culture).TextInfo.ToTitleCase($WindValue.tolower())
  $Sunrise = $Sunrise
  $Sunset = $Sunset

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
    # Weather display section - needs restoration
    Write-Host "Rain conditions detected" -ForegroundColor cyan
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
    #> elseif ($Clear.Contains($XMLData.weather.number) -and $Time -gt 18) {
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
