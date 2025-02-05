<#
.SYNOPSIS
	Lists suggestions
.DESCRIPTION
	This PowerShell script lists  suggestions from Google.
.EXAMPLE
	PS> ./list-suggestions.ps1 Joe
	joe biden
	joe cocker
	...
.PARAMETER text
	Specifies the word or sentence to get suggestions for.
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$text = )

try {
	if ( -eq ) { $text = read-host  }
	$URI = [uri]::escapeuristring()
	$Content = (Invoke-WebRequest -URI $URI -useBasicParsing).Content 
	($Content | ConvertFrom-Json).SyncRoot | Select-Object -Skip 1
	exit 0 # success
} catch {
	
	exit 1
}
