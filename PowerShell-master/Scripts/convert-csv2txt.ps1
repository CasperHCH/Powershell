<#
.SYNOPSIS
	Converts a .CSV file into a text file
.DESCRIPTION
	This PowerShell script converts a .CSV file into a text file and prints it.
.PARAMETER Path
	Specifies the path to the .CSV file
.EXAMPLE
	PS> ./convert-csv2txt salaries.csv
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Path = )

try {
	if ($Path -eq  ) { $Path = read-host  }

	$Table = Import-CSV -path  -header A,B,C,D,E,F,G,H

	foreach($Row in $Table) {
		write-output 
	}
	exit 0 # success
} catch {
	
	exit 1
}
