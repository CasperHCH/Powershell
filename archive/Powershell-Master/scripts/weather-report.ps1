<#
.SYNOPSIS
	Lists the local weather report using secure HTTPS connection

.DESCRIPTION
	This PowerShell script retrieves local weather report from wttr.in service
	using secure HTTPS protocol. Includes input validation and audit logging.

.PARAMETER GeoLocation
	Specifies the geographic location to use (determine automatically by default)
	Must be a valid location name or empty for auto-detection

.EXAMPLE
	PS> .\weather-report.ps1 -GeoLocation "Paris"

.EXAMPLE
	PS> .\weather-report.ps1  # Auto-detect location

.LINK
	https://github.com/fleschutz/PowerShell

.NOTES
	Author: Markus Fleschutz | License: CC0
	Version: 2.0 (Security Enhanced)
	Security Classification: Public
	Requires: PowerShell 5.1+, Internet connectivity
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $false, HelpMessage = "Geographic location (empty for auto-detect)")]
	[ValidateLength(0, 100)]
	[string]$GeoLocation = ""
)

# Audit logging
$auditEntry = @{
	Timestamp    = Get-Date -Format "o"
	Action       = "GetWeatherReport"
	User         = $env:USERNAME
	ComputerName = $env:COMPUTERNAME
	ScriptName   = $MyInvocation.MyCommand.Name
	Location     = $GeoLocation
}

try {
	# Input sanitization for URL safety
	$sanitizedLocation = if ($GeoLocation) {
		[System.Web.HttpUtility]::UrlEncode($GeoLocation.Trim())
	}
 else {
		""
	}

	$uri = "https://v2d.wttr.in/$sanitizedLocation"
	Write-Verbose "Requesting weather data from: $uri"

	# Use HTTPS for secure communication with timeout
	$response = Invoke-WebRequest -Uri $uri -UserAgent "PowerShell/SecureWeatherScript" -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop

	Write-Output $response.Content
	$auditEntry.Status = "Success"
	$auditEntry.ResponseSize = $response.Content.Length

	exit 0 # success
}
catch {
	$errorMsg = "Failed to retrieve weather data: $($_.Exception.Message)"
	Write-Error $errorMsg
	$auditEntry.Status = "Failed"
	$auditEntry.Error = $_.Exception.Message
	exit 1
}
finally {
	# Audit logging (in production, this would go to a centralized log)
	Write-Verbose "Audit: $($auditEntry | ConvertTo-Json -Compress)"
}
