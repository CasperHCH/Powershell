<#
.SYNOPSIS
	Lists the TIOBE index of top programming languages
.DESCRIPTION
	This PowerShell script lists the TIOBE index of top programming languages.
.EXAMPLE
	PS> ./list-tiobe-index.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


	if ($Num -ge 0.875) {
		write-host -noNewLine 
	} elseif ($Num -ge 0.75) {
		write-host -noNewLine 
	} elseif ($Num -ge 0.625) {
		write-host -noNewLine 
	} elseif ($Num -ge 0.5) {
		write-host -noNewLine 
	} elseif ($Num -ge 0.375) {
		write-host -noNewLine 
	} elseif ($Num -ge 0.25) {
		write-host -noNewLine 
	} elseif ($Num -ge 0.125) {
		write-host -noNewLine 
	}
	write-host -noNewLine 
	if ($Change -ge 0.0) {
		write-host -foregroundColor green 
	} else {
		write-host -foregroundColor red 
	}
}

try {
	& write-big.ps1 
	
	

	$Table = import-csv 
	foreach($Row in $Table) {
		[string]$Name = $Row.Language
		[float]$Value = $Row.Popularity
		[float]$Change = $Row.Change
		WriteBar $Name $Value 14.0 $Change
	}
	exit 0 # success
} catch {
	
	exit 1
}
