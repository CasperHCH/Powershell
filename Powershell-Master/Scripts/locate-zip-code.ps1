<#
.SYNOPSIS
	Prints the geo location of a zip-code
.DESCRIPTION
	This PowerShell script prints the geographic location of the given zip-code.
.PARAMETER CountryCode
	Specifies the country code
.PARAMETER ZipCode
	Specifies the zip code
.EXAMPLE
	PS> ./locate-zip-code.ps1 de 87600
	* DE 87600 Kaufbeuren is at 47.8824°N, 10.6219°W
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$CountryCode = , [string]$ZipCode = )

try {
	if ($CountryCode -eq  ) { $CountryCode = read-host  }
	if ($ZipCode -eq  ) { $ZipCode = read-host  }

	write-progress 
	$Table = import-csv 

	$FoundOne = 0
	foreach($Row in $Table) {
		if ($Row.country -eq $CountryCode) {
			if ($Row.postal_code -eq $ZipCode) {
				$Country=$Row.country
				$City = $Row.city
				$Lat = $Row.latitude
				$Lon = $Row.longitude
				write-output 
				$FoundOne = 1
			}
		}
	}

	if ($FoundOne) {
		exit 0 # success
	}
	throw 
} catch {
	
	exit 1
}
