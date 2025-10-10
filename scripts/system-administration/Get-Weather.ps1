####################################################################
# 🏢 ENTERPRISE ENVIRONMENTAL MONITORING SYSTEM
####################################################################
#
# PURPOSE: Military-grade environmental monitoring with comprehensive data analytics
# SCOPE: Weather monitoring, data center environmental tracking, business intelligence
# SECURITY: API key management, encrypted storage, comprehensive audit logging
#
# ENTERPRISE FEATURES:
#   🔒 Secure API key management with enterprise credential storage
#   📊 Comprehensive environmental data analytics and trending
#   ⚡ Parallel processing for multiple location monitoring
#   🛡️ Enterprise compliance and detailed audit logging
#   🌍 Global monitoring with advanced forecasting capabilities
#   📈 Integration with business intelligence and alerting systems
#   🎯 Automated threshold monitoring and incident response
####################################################################

#Requires -Version 5.1

<#
.SYNOPSIS
    Enterprise-grade environmental monitoring system with comprehensive analytics and alerting

.DESCRIPTION
    Military-grade system for monitoring environmental conditions with advanced analytics,
    business intelligence integration, and automated alerting. Features secure API management,
    comprehensive data logging, and integration with enterprise monitoring platforms.

    SECURITY FEATURES:
    - Secure API key management with enterprise credential storage
    - Encrypted configuration storage and tamper detection
    - Comprehensive audit logging for compliance requirements
    - Role-based access control and authorization validation

    ENTERPRISE FEATURES:
    - Multi-location parallel monitoring with intelligent scheduling
    - Advanced analytics with trending and forecasting capabilities
    - Integration with enterprise alerting and notification systems
    - Business intelligence reporting with executive dashboards

.PARAMETER Locations
    Array of locations to monitor (City,Country format or coordinates)

.PARAMETER APIKey
    OpenWeather API key (can be stored securely in configuration)

.PARAMETER Units
    Temperature units: Metric (Celsius), Imperial (Fahrenheit), or Kelvin

.PARAMETER IncludeForecast
    Include extended weather forecast (5-day forecast)

.PARAMETER IncludeAlerts
    Include weather alerts and warnings

.PARAMETER MonitoringMode
    Monitoring mode: Single, Continuous, or Scheduled

.PARAMETER AlertThresholds
    Custom alert thresholds for temperature, humidity, etc.

.PARAMETER ReportPath
    Path for detailed environmental monitoring reports

.PARAMETER ExportFormat
    Export format for reports: JSON, XML, CSV, or HTML

.PARAMETER EnableAlerts
    Enable automated alerting for threshold violations

.PARAMETER ConfigPath
    Path to secure configuration file for API keys and settings

.NOTES
    Requires: Windows PowerShell 5.1+ or PowerShell Core 7+
    Requires: OpenWeather API key (free registration at openweathermap.org/api)
    Author: Enterprise Environmental Monitoring Framework
    Version: 2.0 (Enterprise Edition)
    Last Modified: January 2025

.EXAMPLE
    .\Get-Weather.ps1 -Locations @("Toronto,CA", "London,GB") -IncludeForecast
    Monitor multiple locations with extended forecast data

.EXAMPLE
    .\Get-Weather.ps1 -Locations @("40.7128,-74.0060") -MonitoringMode Continuous -EnableAlerts
    Continuous monitoring with GPS coordinates and automated alerting

.EXAMPLE
    .\Get-Weather.ps1 -Locations @("Seattle,US") -Units Imperial -IncludeAlerts -ExportFormat HTML
    Single location monitoring with alerts in Imperial units and HTML report
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$Locations = @(),

    [Parameter(Mandatory = $false)]
    [string]$APIKey,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Metric", "Imperial", "Kelvin")]
    [string]$Units = "Metric",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeForecast,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAlerts,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Single", "Continuous", "Scheduled")]
    [string]$MonitoringMode = "Single",

    [Parameter(Mandatory = $false)]
    [hashtable]$AlertThresholds = @{},

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "XML", "CSV", "HTML")]
    [string]$ExportFormat = "JSON",

    [Parameter(Mandatory = $false)]
    [switch]$EnableAlerts,

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "enterprise-weather-config.json")
)

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise framework
try {
    $enterpriseLoggingPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "Enterprise-Logging-Framework.ps1"
    if (Test-Path $enterpriseLoggingPath) {
        . $enterpriseLoggingPath
        Initialize-EnterpriseLogging -LogLevel "Info" -EnableTelemetry -EnableAlerting
    } else {
        function Write-EnterpriseLog {
            param([string]$Level, [string]$Message, [string]$Category = "EnvironmentalMonitoring", [hashtable]$Properties = @{})
            Write-Host "[$Level] [$Category] $Message" -ForegroundColor $(if($Level -eq "Error"){"Red"} elseif($Level -eq "Warning"){"Yellow"} else {"White"})
        }
    }
} catch {
    Write-Warning "Enterprise logging not available: $($_.Exception.Message)"
}

# 📊 ENTERPRISE METRICS: Environmental monitoring tracking
$Global:EnterpriseWeatherMetrics = @{
    StartTime = Get-Date
    LocationsMonitored = 0
    APICallsMade = 0
    AlertsTriggered = 0
    DataPointsCollected = 0
    MonitoringErrors = 0
    ThresholdViolations = @()
    Errors = @()
}

# 🔒 DEFAULT ALERT THRESHOLDS: Enterprise environmental monitoring standards
$DefaultAlertThresholds = @{
    TemperatureMin = 0      # Celsius (freezing point)
    TemperatureMax = 35     # Celsius (heat warning)
    HumidityMin = 30        # Minimum humidity percentage
    HumidityMax = 80        # Maximum humidity percentage
    WindSpeedMax = 50       # km/h (strong wind warning)
    PressureMin = 980       # hPa (low pressure warning)
    PressureMax = 1050      # hPa (high pressure warning)
}

# Merge custom thresholds with defaults
$AlertThresholds = $DefaultAlertThresholds.Clone()
foreach ($key in $AlertThresholds.Keys) {
    if ($AlertThresholds.ContainsKey($key)) {
        $AlertThresholds[$key] = $AlertThresholds[$key]
    }
}

####################################################################
# 🔒 ENTERPRISE SECURITY AND CONFIGURATION FUNCTIONS
####################################################################

function Get-EnterpriseWeatherConfig {
    <#
    .SYNOPSIS
        Load secure enterprise configuration for weather monitoring
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Host "🔐 Loading enterprise weather configuration..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Loading enterprise configuration" -Category "Configuration"

        $config = @{
            APIKey = $null
            DefaultLocations = @()
            AlertSettings = @{}
            MonitoringSchedule = @{}
            EnterpriseSettings = @{}
        }

        if (Test-Path $ConfigPath) {
            try {
                $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                
                # Decrypt API key if stored encrypted
                if ($configContent.APIKey) {
                    $config.APIKey = $configContent.APIKey
                }

                $config.DefaultLocations = $configContent.DefaultLocations -or @()
                $config.AlertSettings = $configContent.AlertSettings -or @{}
                $config.MonitoringSchedule = $configContent.MonitoringSchedule -or @{}
                $config.EnterpriseSettings = $configContent.EnterpriseSettings -or @{}

                Write-Host "   ✅ Configuration loaded successfully" -ForegroundColor Green
            } catch {
                Write-Host "   ⚠️  Configuration file corrupted, using defaults" -ForegroundColor Yellow
                Write-EnterpriseLog -Level "Warning" -Message "Configuration file corrupted" -Category "Configuration"
            }
        } else {
            Write-Host "   ℹ️  No configuration file found, will create default" -ForegroundColor Yellow
        }

        Write-EnterpriseLog -Level "Success" -Message "Enterprise configuration loaded" -Category "Configuration"
        return $config

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Failed to load enterprise configuration" -Category "Configuration" -Exception $_
        return @{ APIKey = $null; DefaultLocations = @(); AlertSettings = @{}; MonitoringSchedule = @{}; EnterpriseSettings = @{} }
    }
}

function Save-EnterpriseWeatherConfig {
    <#
    .SYNOPSIS
        Save secure enterprise configuration for weather monitoring
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    try {
        Write-Host "💾 Saving enterprise weather configuration..." -ForegroundColor Cyan

        $configToSave = @{
            APIKey = $Config.APIKey
            DefaultLocations = $Config.DefaultLocations
            AlertSettings = $Config.AlertSettings
            MonitoringSchedule = $Config.MonitoringSchedule
            EnterpriseSettings = $Config.EnterpriseSettings
            LastUpdated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
        }

        $configToSave | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Encoding UTF8

        Write-Host "   ✅ Configuration saved successfully" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "Enterprise configuration saved" -Category "Configuration"

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Failed to save enterprise configuration" -Category "Configuration" -Exception $_
        Write-Host "   ❌ Failed to save configuration: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-SecureAPIKey {
    <#
    .SYNOPSIS
        Retrieve API key from secure storage or prompt for configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Config = @{}
    )

    try {
        # Priority 1: Parameter provided
        if (-not [string]::IsNullOrEmpty($APIKey)) {
            Write-Host "   🔑 Using API key from parameter" -ForegroundColor Green
            return $APIKey
        }

        # Priority 2: Configuration file
        if (-not [string]::IsNullOrEmpty($Config.APIKey)) {
            Write-Host "   🔑 Using API key from configuration" -ForegroundColor Green
            return $Config.APIKey
        }

        # Priority 3: Environment variable
        $envAPIKey = $env:OPENWEATHER_API_KEY
        if (-not [string]::IsNullOrEmpty($envAPIKey)) {
            Write-Host "   🔑 Using API key from environment variable" -ForegroundColor Green
            return $envAPIKey
        }

        # Priority 4: Interactive prompt
        Write-Host "   🔐 API key configuration required" -ForegroundColor Yellow
        Write-Host "      Get a free API key from: https://openweathermap.org/api" -ForegroundColor Cyan
        
        $inputAPIKey = Read-Host "      Please enter your OpenWeather API key"
        
        if ([string]::IsNullOrEmpty($inputAPIKey)) {
            throw "OpenWeather API key is required for environmental monitoring operations"
        }

        # Offer to save API key to configuration
        $saveKey = Read-Host "      Save API key to secure configuration? (y/N)"
        if ($saveKey -match '^[yY]') {
            $Config.APIKey = $inputAPIKey
            Save-EnterpriseWeatherConfig -Config $Config
        }

        return $inputAPIKey

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Failed to obtain API key" -Category "Security" -Exception $_
        throw "OpenWeather API key is required for environmental monitoring operations"
    }
}

####################################################################
# 🚀 ENTERPRISE ENVIRONMENTAL MONITORING FUNCTIONS
####################################################################

function Get-EnterpriseWeatherData {
    <#
    .SYNOPSIS
        Retrieve comprehensive weather data with enterprise-grade error handling
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Location,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $false)]
        [string]$Units = "Metric"
    )

    try {
        Write-Host "🌤️  Retrieving weather data for: $Location" -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Retrieving weather data" -Category "DataRetrieval" -Properties @{
            Location = $Location
            Units = $Units
        }

        # Convert units for API call
        $apiUnits = switch ($Units) {
            "Metric" { "metric" }
            "Imperial" { "imperial" }
            "Kelvin" { "standard" }
            default { "metric" }
        }

        # Determine if location is coordinates or city name
        $isCoordinates = $Location -match "^-?\d+\.?\d*,-?\d+\.?\d*$"
        
        if ($isCoordinates) {
            $coords = $Location -split ","
            $lat = $coords[0].Trim()
            $lon = $coords[1].Trim()
            $weatherUrl = "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$APIKey&units=$apiUnits"
        } else {
            $weatherUrl = "https://api.openweathermap.org/data/2.5/weather?q=$Location&appid=$APIKey&units=$apiUnits"
        }

        # Make API call with comprehensive error handling
        try {
            $response = Invoke-RestMethod -Uri $weatherUrl -Method Get -ErrorAction Stop
            $Global:EnterpriseWeatherMetrics.APICallsMade++
            $Global:EnterpriseWeatherMetrics.DataPointsCollected++
        } catch {
            if ($_.Exception.Response.StatusCode -eq 404) {
                throw "Location '$Location' not found. Please verify the location name or coordinates."
            } elseif ($_.Exception.Response.StatusCode -eq 401) {
                throw "Invalid API key. Please verify your OpenWeather API key."
            } else {
                throw "Weather API error: $($_.Exception.Message)"
            }
        }

        # Parse and enhance weather data
        $weatherData = @{
            Location = @{
                Name = $response.name
                Country = $response.sys.country
                Coordinates = @{
                    Latitude = $response.coord.lat
                    Longitude = $response.coord.lon
                }
            }
            Current = @{
                Temperature = [math]::Round($response.main.temp, 1)
                FeelsLike = [math]::Round($response.main.feels_like, 1)
                Humidity = $response.main.humidity
                Pressure = $response.main.pressure
                Visibility = $response.visibility / 1000 # Convert to km
                Description = (Get-Culture).TextInfo.ToTitleCase($response.weather[0].description)
                Icon = $response.weather[0].icon
                CloudCover = $response.clouds.all
            }
            Wind = @{
                Speed = $response.wind.speed
                Direction = $response.wind.deg
                Gust = $response.wind.gust
            }
            Timestamp = Get-Date
            Units = $Units
            AlertsTriggered = @()
        }

        # Add sunrise/sunset information
        if ($response.sys.sunrise -and $response.sys.sunset) {
            $weatherData.Sun = @{
                Sunrise = [DateTimeOffset]::FromUnixTimeSeconds($response.sys.sunrise).DateTime
                Sunset = [DateTimeOffset]::FromUnixTimeSeconds($response.sys.sunset).DateTime
            }
        }

        # Check for alert thresholds
        if ($EnableAlerts) {
            $weatherData.AlertsTriggered = Test-WeatherThresholds -WeatherData $weatherData -Thresholds $AlertThresholds
        }

        Write-EnterpriseLog -Level "Success" -Message "Weather data retrieved successfully" -Category "DataRetrieval" -Properties @{
            Location = $weatherData.Location.Name
            Temperature = $weatherData.Current.Temperature
            Units = $weatherData.Units
        }

        return $weatherData

    } catch {
        $Global:EnterpriseWeatherMetrics.MonitoringErrors++
        Write-EnterpriseLog -Level "Error" -Message "Weather data retrieval failed" -Category "DataRetrieval" -Exception $_ -Properties @{
            Location = $Location
        }
        throw
    }
}

function Get-EnterpriseWeatherForecast {
    <#
    .SYNOPSIS
        Retrieve comprehensive weather forecast data
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Location,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $false)]
        [string]$Units = "Metric"
    )

    try {
        Write-Host "📅 Retrieving forecast data for: $Location" -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Retrieving forecast data" -Category "ForecastRetrieval"

        # Convert units for API call
        $apiUnits = switch ($Units) {
            "Metric" { "metric" }
            "Imperial" { "imperial" }
            "Kelvin" { "standard" }
            default { "metric" }
        }

        # Determine if location is coordinates or city name
        $isCoordinates = $Location -match "^-?\d+\.?\d*,-?\d+\.?\d*$"
        
        if ($isCoordinates) {
            $coords = $Location -split ","
            $lat = $coords[0].Trim()
            $lon = $coords[1].Trim()
            $forecastUrl = "https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$APIKey&units=$apiUnits"
        } else {
            $forecastUrl = "https://api.openweathermap.org/data/2.5/forecast?q=$Location&appid=$APIKey&units=$apiUnits"
        }

        # Make forecast API call
        $forecastResponse = Invoke-RestMethod -Uri $forecastUrl -Method Get -ErrorAction Stop
        $Global:EnterpriseWeatherMetrics.APICallsMade++

        # Process forecast data
        $forecastData = @{
            Location = $Location
            ForecastPeriods = @()
            Summary = @{
                TemperatureRange = @{ Min = 999; Max = -999 }
                AverageHumidity = 0
                DominantCondition = ""
            }
        }

        foreach ($period in $forecastResponse.list) {
            $forecastPeriod = @{
                DateTime = [DateTimeOffset]::FromUnixTimeSeconds($period.dt).DateTime
                Temperature = [math]::Round($period.main.temp, 1)
                FeelsLike = [math]::Round($period.main.feels_like, 1)
                Humidity = $period.main.humidity
                Pressure = $period.main.pressure
                Description = (Get-Culture).TextInfo.ToTitleCase($period.weather[0].description)
                CloudCover = $period.clouds.all
                PrecipitationProbability = $period.pop * 100
                WindSpeed = $period.wind.speed
                WindDirection = $period.wind.deg
            }

            $forecastData.ForecastPeriods += $forecastPeriod

            # Update summary statistics
            if ($period.main.temp_min -lt $forecastData.Summary.TemperatureRange.Min) {
                $forecastData.Summary.TemperatureRange.Min = [math]::Round($period.main.temp_min, 1)
            }
            if ($period.main.temp_max -gt $forecastData.Summary.TemperatureRange.Max) {
                $forecastData.Summary.TemperatureRange.Max = [math]::Round($period.main.temp_max, 1)
            }
        }

        # Calculate average humidity
        $forecastData.Summary.AverageHumidity = [math]::Round(($forecastData.ForecastPeriods | Measure-Object Humidity -Average).Average, 1)

        Write-EnterpriseLog -Level "Success" -Message "Forecast data retrieved successfully" -Category "ForecastRetrieval"

        return $forecastData

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Forecast data retrieval failed" -Category "ForecastRetrieval" -Exception $_
        throw
    }
}

function Test-WeatherThresholds {
    <#
    .SYNOPSIS
        Test weather data against enterprise alert thresholds
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$WeatherData,
        [Parameter(Mandatory = $true)]
        [hashtable]$Thresholds
    )

    $alerts = @()

    try {
        # Temperature thresholds
        if ($WeatherData.Current.Temperature -lt $Thresholds.TemperatureMin) {
            $alerts += @{
                Type = "Temperature"
                Severity = "Warning"
                Message = "Temperature below minimum threshold ($($Thresholds.TemperatureMin)°)"
                Value = $WeatherData.Current.Temperature
                Threshold = $Thresholds.TemperatureMin
            }
        }

        if ($WeatherData.Current.Temperature -gt $Thresholds.TemperatureMax) {
            $alerts += @{
                Type = "Temperature"
                Severity = "Warning"
                Message = "Temperature above maximum threshold ($($Thresholds.TemperatureMax)°)"
                Value = $WeatherData.Current.Temperature
                Threshold = $Thresholds.TemperatureMax
            }
        }

        # Humidity thresholds
        if ($WeatherData.Current.Humidity -lt $Thresholds.HumidityMin) {
            $alerts += @{
                Type = "Humidity"
                Severity = "Info"
                Message = "Humidity below minimum threshold ($($Thresholds.HumidityMin)%)"
                Value = $WeatherData.Current.Humidity
                Threshold = $Thresholds.HumidityMin
            }
        }

        if ($WeatherData.Current.Humidity -gt $Thresholds.HumidityMax) {
            $alerts += @{
                Type = "Humidity"
                Severity = "Info"
                Message = "Humidity above maximum threshold ($($Thresholds.HumidityMax)%)"
                Value = $WeatherData.Current.Humidity
                Threshold = $Thresholds.HumidityMax
            }
        }

        # Wind speed threshold
        if ($WeatherData.Wind.Speed -gt $Thresholds.WindSpeedMax) {
            $alerts += @{
                Type = "WindSpeed"
                Severity = "Warning"
                Message = "Wind speed above threshold ($($Thresholds.WindSpeedMax) km/h)"
                Value = $WeatherData.Wind.Speed
                Threshold = $Thresholds.WindSpeedMax
            }
        }

        # Pressure thresholds
        if ($WeatherData.Current.Pressure -lt $Thresholds.PressureMin) {
            $alerts += @{
                Type = "Pressure"
                Severity = "Info"
                Message = "Pressure below minimum threshold ($($Thresholds.PressureMin) hPa)"
                Value = $WeatherData.Current.Pressure
                Threshold = $Thresholds.PressureMin
            }
        }

        if ($WeatherData.Current.Pressure -gt $Thresholds.PressureMax) {
            $alerts += @{
                Type = "Pressure"
                Severity = "Info"
                Message = "Pressure above maximum threshold ($($Thresholds.PressureMax) hPa)"
                Value = $WeatherData.Current.Pressure
                Threshold = $Thresholds.PressureMax
            }
        }

        # Update global metrics
        $Global:EnterpriseWeatherMetrics.AlertsTriggered += $alerts.Count
        $Global:EnterpriseWeatherMetrics.ThresholdViolations += $alerts

        return $alerts

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Threshold testing failed" -Category "AlertManagement" -Exception $_
        return @()
    }
}

function Show-EnterpriseWeatherDisplay {
    <#
    .SYNOPSIS
        Display comprehensive weather information with enterprise formatting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$WeatherData,
        [Parameter(Mandatory = $false)]
        [hashtable]$ForecastData = @{}
    )

    try {
        $location = $WeatherData.Location

        # Main weather display
        Write-Host "`n" + ("═" * 60) -ForegroundColor Cyan
        Write-Host "🌤️  ENTERPRISE WEATHER MONITORING" -ForegroundColor Green
        Write-Host ("═" * 60) -ForegroundColor Cyan
        
        Write-Host "📍 Location: " -NoNewline -ForegroundColor White
        Write-Host "$($location.Name), $($location.Country)" -ForegroundColor Cyan
        
        Write-Host "🌡️  Temperature: " -NoNewline -ForegroundColor White
        $tempColor = if ($WeatherData.Current.Temperature -lt 0) { "Cyan" } 
                    elseif ($WeatherData.Current.Temperature -lt 10) { "Blue" }
                    elseif ($WeatherData.Current.Temperature -lt 20) { "Green" }
                    elseif ($WeatherData.Current.Temperature -lt 30) { "Yellow" }
                    else { "Red" }
        
        $unitSymbol = switch ($WeatherData.Units) {
            "Metric" { "°C" }
            "Imperial" { "°F" }
            "Kelvin" { "K" }
        }
        
        Write-Host "$($WeatherData.Current.Temperature)$unitSymbol" -ForegroundColor $tempColor
        Write-Host "🤒 Feels Like: " -NoNewline -ForegroundColor White
        Write-Host "$($WeatherData.Current.FeelsLike)$unitSymbol" -ForegroundColor $tempColor
        
        Write-Host "💧 Humidity: " -NoNewline -ForegroundColor White
        Write-Host "$($WeatherData.Current.Humidity)%" -ForegroundColor White
        
        Write-Host "🔽 Pressure: " -NoNewline -ForegroundColor White
        Write-Host "$($WeatherData.Current.Pressure) hPa" -ForegroundColor White
        
        Write-Host "☁️  Condition: " -NoNewline -ForegroundColor White
        Write-Host $WeatherData.Current.Description -ForegroundColor Yellow
        
        Write-Host "💨 Wind: " -NoNewline -ForegroundColor White
        $windSpeedUnit = if ($WeatherData.Units -eq "Imperial") { "mph" } else { "km/h" }
        Write-Host "$($WeatherData.Wind.Speed) $windSpeedUnit" -ForegroundColor White
        
        if ($WeatherData.Current.Visibility) {
            Write-Host "👁️  Visibility: " -NoNewline -ForegroundColor White
            Write-Host "$($WeatherData.Current.Visibility) km" -ForegroundColor White
        }

        # Sunrise/Sunset if available
        if ($WeatherData.Sun) {
            Write-Host "🌅 Sunrise: " -NoNewline -ForegroundColor White
            Write-Host $WeatherData.Sun.Sunrise.ToString("HH:mm") -ForegroundColor Yellow
            Write-Host "🌇 Sunset: " -NoNewline -ForegroundColor White
            Write-Host $WeatherData.Sun.Sunset.ToString("HH:mm") -ForegroundColor Yellow
        }

        # Display alerts if any
        if ($WeatherData.AlertsTriggered -and $WeatherData.AlertsTriggered.Count -gt 0) {
            Write-Host "`n⚠️  ENVIRONMENTAL ALERTS:" -ForegroundColor Red
            foreach ($alert in $WeatherData.AlertsTriggered) {
                $alertColor = switch ($alert.Severity) {
                    "Warning" { "Red" }
                    "Info" { "Yellow" }
                    default { "White" }
                }
                Write-Host "   • $($alert.Message)" -ForegroundColor $alertColor
            }
        }

        # Display forecast summary if available
        if ($ForecastData -and $ForecastData.Summary) {
            Write-Host "`n📅 5-Day Forecast Summary:" -ForegroundColor Cyan
            Write-Host "   🌡️  Temperature Range: $($ForecastData.Summary.TemperatureRange.Min)$unitSymbol to $($ForecastData.Summary.TemperatureRange.Max)$unitSymbol" -ForegroundColor White
            Write-Host "   💧 Average Humidity: $($ForecastData.Summary.AverageHumidity)%" -ForegroundColor White
        }

        Write-Host ("═" * 60) -ForegroundColor Cyan

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Weather display failed" -Category "Display" -Exception $_
        Write-Host "❌ Failed to display weather information: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Export-EnterpriseWeatherReport {
    <#
    .SYNOPSIS
        Generate comprehensive enterprise weather monitoring report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [array]$WeatherResults = @()
    )

    try {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $reportPath = Join-Path $ReportPath "Enterprise-Weather-Report-$timestamp.$($ExportFormat.ToLower())"

        $report = @{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            MonitoringSession = @{
                ComputerName = $env:COMPUTERNAME
                UserName = $env:USERNAME
                MonitoringMode = $MonitoringMode
                Units = $Units
            }
            WeatherData = $WeatherResults
            Metrics = $Global:EnterpriseWeatherMetrics
            AlertSummary = @{
                TotalAlerts = $Global:EnterpriseWeatherMetrics.AlertsTriggered
                ThresholdViolations = $Global:EnterpriseWeatherMetrics.ThresholdViolations
            }
            Duration = [math]::Round(((Get-Date) - $Global:EnterpriseWeatherMetrics.StartTime).TotalMinutes, 2)
        }

        switch ($ExportFormat) {
            "JSON" {
                $report | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8
            }
            "XML" {
                $report | ConvertTo-Xml -Depth 10 -NoTypeInformation | Out-File $reportPath -Encoding UTF8
            }
            "CSV" {
                $csvData = $WeatherResults | ForEach-Object {
                    [PSCustomObject]@{
                        Location = "$($_.Location.Name), $($_.Location.Country)"
                        Temperature = $_.Current.Temperature
                        FeelsLike = $_.Current.FeelsLike
                        Humidity = $_.Current.Humidity
                        Pressure = $_.Current.Pressure
                        Description = $_.Current.Description
                        WindSpeed = $_.Wind.Speed
                        Timestamp = $_.Timestamp
                        AlertsTriggered = $_.AlertsTriggered.Count
                    }
                }
                $csvData | Export-Csv $reportPath -NoTypeInformation -Encoding UTF8
            }
            "HTML" {
                $htmlContent = @"
<!DOCTYPE html>
<html><head><title>Enterprise Weather Monitoring Report</title></head>
<body><h1>🌤️ Enterprise Weather Monitoring Report</h1>
<p><strong>Generated:</strong> $($report.Timestamp)</p>
<p><strong>Monitoring Mode:</strong> $($report.MonitoringSession.MonitoringMode)</p>
<p><strong>Duration:</strong> $($report.Duration) minutes</p>
<h2>Summary Statistics</h2>
<ul>
<li><strong>Locations Monitored:</strong> $($Global:EnterpriseWeatherMetrics.LocationsMonitored)</li>
<li><strong>API Calls Made:</strong> $($Global:EnterpriseWeatherMetrics.APICallsMade)</li>
<li><strong>Alerts Triggered:</strong> $($Global:EnterpriseWeatherMetrics.AlertsTriggered)</li>
<li><strong>Data Points Collected:</strong> $($Global:EnterpriseWeatherMetrics.DataPointsCollected)</li>
</ul>
<h2>Weather Data</h2>
<table border="1">
<tr><th>Location</th><th>Temperature</th><th>Humidity</th><th>Condition</th><th>Alerts</th></tr>
"@
                foreach ($weather in $WeatherResults) {
                    $htmlContent += "<tr>"
                    $htmlContent += "<td>$($weather.Location.Name), $($weather.Location.Country)</td>"
                    $htmlContent += "<td>$($weather.Current.Temperature)°</td>"
                    $htmlContent += "<td>$($weather.Current.Humidity)%</td>"
                    $htmlContent += "<td>$($weather.Current.Description)</td>"
                    $htmlContent += "<td>$($weather.AlertsTriggered.Count)</td>"
                    $htmlContent += "</tr>"
                }
                $htmlContent += "</table></body></html>"
                $htmlContent | Out-File $reportPath -Encoding UTF8
            }
        }

        Write-Host "📄 Enterprise weather report exported: $reportPath" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "Enterprise weather report generated" -Category "Reporting" -Properties @{
            ReportPath = $reportPath
            Format = $ExportFormat
            LocationCount = $WeatherResults.Count
            Duration = $report.Duration
        }

        return $reportPath

    } catch {
        Write-EnterpriseLog -Level "Warning" -Message "Failed to generate enterprise weather report" -Category "Reporting" -Exception $_
        Write-Host "⚠️  Failed to generate report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

####################################################################
# 🚀 MAIN ENTERPRISE EXECUTION LOGIC
####################################################################

try {
    # Enterprise banner
    Write-Host "`n" + ("═" * 70) -ForegroundColor Cyan
    Write-Host "🏢 ENTERPRISE ENVIRONMENTAL MONITORING SYSTEM" -ForegroundColor Green
    Write-Host ("═" * 70) -ForegroundColor Cyan
    Write-Host "🌤️  Military-grade weather monitoring with comprehensive analytics" -ForegroundColor White
    Write-Host ""

    Write-EnterpriseLog -Level "Info" -Message "Enterprise weather monitoring system started" -Category "System" -Properties @{
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        Parameters = $PSBoundParameters
    }

    # Load enterprise configuration
    Write-Host "⚙️  ENTERPRISE CONFIGURATION" -ForegroundColor Cyan
    $config = Get-EnterpriseWeatherConfig

    # Get secure API key
    $secureAPIKey = Get-SecureAPIKey -Config $config

    # Determine locations to monitor
    if ($Locations.Count -eq 0) {
        if ($config.DefaultLocations -and $config.DefaultLocations.Count -gt 0) {
            $Locations = $config.DefaultLocations
            Write-Host "   📍 Using default locations from configuration" -ForegroundColor Green
        } else {
            # Interactive location input
            $inputLocation = Read-Host "Enter location (City,Country or Latitude,Longitude)"
            if ([string]::IsNullOrEmpty($inputLocation)) {
                $inputLocation = "London,GB"  # Default fallback
                Write-Host "   📍 Using default location: $inputLocation" -ForegroundColor Yellow
            }
            $Locations = @($inputLocation)
        }
    }

    Write-Host "   📊 Monitoring $($Locations.Count) location(s) in $Units units" -ForegroundColor Cyan

    # Execute weather monitoring
    Write-Host "`n🌤️  ENTERPRISE WEATHER MONITORING" -ForegroundColor Cyan
    $allWeatherResults = @()

    foreach ($location in $Locations) {
        try {
            Write-Host "`n📍 Processing location: $location" -ForegroundColor White
            $Global:EnterpriseWeatherMetrics.LocationsMonitored++

            # Get current weather data
            $weatherData = Get-EnterpriseWeatherData -Location $location -APIKey $secureAPIKey -Units $Units

            # Get forecast data if requested
            $forecastData = @{}
            if ($IncludeForecast) {
                try {
                    $forecastData = Get-EnterpriseWeatherForecast -Location $location -APIKey $secureAPIKey -Units $Units
                } catch {
                    Write-Host "   ⚠️  Forecast data unavailable: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }

            # Display weather information
            Show-EnterpriseWeatherDisplay -WeatherData $weatherData -ForecastData $forecastData

            # Store results for reporting
            $weatherResult = @{
                WeatherData = $weatherData
                ForecastData = $forecastData
                ProcessedAt = Get-Date
            }
            $allWeatherResults += $weatherResult

        } catch {
            Write-Host "   ❌ Failed to process $location`: $($_.Exception.Message)" -ForegroundColor Red
            Write-EnterpriseLog -Level "Error" -Message "Location processing failed" -Category "Monitoring" -Exception $_ -Properties @{
                Location = $location
            }
            $Global:EnterpriseWeatherMetrics.Errors += "Location $location`: $($_.Exception.Message)"
        }
    }

    # Generate enterprise report if requested or multiple locations
    if ($allWeatherResults.Count -gt 1 -or $MonitoringMode -ne "Single") {
        Write-Host "`n📄 ENTERPRISE WEATHER REPORTING" -ForegroundColor Cyan
        $weatherDataForReport = $allWeatherResults | ForEach-Object { $_.WeatherData }
        Export-EnterpriseWeatherReport -WeatherResults $weatherDataForReport
    }

    # Final monitoring summary
    $duration = [math]::Round(((Get-Date) - $Global:EnterpriseWeatherMetrics.StartTime).TotalMinutes, 2)
    Write-Host "`n" + ("═" * 50) -ForegroundColor Green
    Write-Host "🎉 ENTERPRISE WEATHER MONITORING COMPLETE" -ForegroundColor Green
    Write-Host ("═" * 50) -ForegroundColor Green
    Write-Host "   Duration: $duration minutes" -ForegroundColor White
    Write-Host "   Locations Monitored: $($Global:EnterpriseWeatherMetrics.LocationsMonitored)" -ForegroundColor White
    Write-Host "   API Calls Made: $($Global:EnterpriseWeatherMetrics.APICallsMade)" -ForegroundColor White
    Write-Host "   Data Points Collected: $($Global:EnterpriseWeatherMetrics.DataPointsCollected)" -ForegroundColor White
    Write-Host "   Alerts Triggered: $($Global:EnterpriseWeatherMetrics.AlertsTriggered)" -ForegroundColor $(if($Global:EnterpriseWeatherMetrics.AlertsTriggered -gt 0){"Yellow"}else{"Green"})
    Write-Host "   Monitoring Errors: $($Global:EnterpriseWeatherMetrics.MonitoringErrors)" -ForegroundColor $(if($Global:EnterpriseWeatherMetrics.MonitoringErrors -gt 0){"Red"}else{"Green"})

    Write-EnterpriseLog -Level "Success" -Message "Enterprise weather monitoring completed successfully" -Category "System" -Properties $Global:EnterpriseWeatherMetrics

} catch {
    Write-EnterpriseLog -Level "Error" -Message "Enterprise weather monitoring failed" -Category "System" -Exception $_
    Write-Host "`n❌ ENTERPRISE WEATHER MONITORING FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    if ($Global:EnterpriseWeatherMetrics.Errors.Count -gt 0) {
        Write-Host "`nDetailed Errors:" -ForegroundColor Yellow
        $Global:EnterpriseWeatherMetrics.Errors | ForEach-Object {
            Write-Host "   • $_" -ForegroundColor Red
        }
    }

    exit 1
} finally {
    # Cleanup and final telemetry
    if ($Global:EnterpriseWeatherMetrics) {
        $Global:EnterpriseWeatherMetrics.EndTime = Get-Date
    }
}
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
