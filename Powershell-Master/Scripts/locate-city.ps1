<#
.SYNOPSIS
	Prints the geographic location of a city
.DESCRIPTION
	This PowerShell script prints the geographic location of the given city.
.PARAMETER City
	Specifies the city to look for
.EXAMPLE
	PS> ./locate-city.ps1 Paris
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$City = )

try {
	if ($City -eq  ) { $City = Read-Host  }

	Write-Progress 
	$Table = import-csv 

	$FoundOne = 0
	foreach($Row in $Table) {
		if ($Row.city -eq $City) {
			$FoundOne = 1
			$Country = $Row.country
			$Region = $Row.admin_name
			$Lat = $Row.lat
			$Long = $Row.lng
			$Population = $Row.population
			write-host 
		}
	}

	if ($FoundOne) {
		exit 0 # success
	}
	write-error 
	exit 1
} catch {
	
	exit 1
}
