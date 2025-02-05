<#
.SYNOPSIS
	Lists details of all countries
.DESCRIPTION
	This PowerShell script lists details of all countries.
.EXAMPLE
	PS> ./list-countries.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


	}
}

try {
	ListCountries | format-table -property Country,Capital,Population,TLD,Phone
	exit 0 # success
} catch {
	
	exit 1
}
