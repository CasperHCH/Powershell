<#
.SYNOPSIS
	List coffee prices
.DESCRIPTION
	This PowerShell script queries alphavantage.co and lists the global price of coffee (monthly, in cents per points).
.EXAMPLE
	PS> ./list-coffee-prices.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


	if ($Num -ge 0.875) {
		Write-Host  -noNewline
	} elseif ($Num -ge 0.75) {
		Write-Host  -noNewline
	} elseif ($Num -ge 0.625) {
		Write-Host  -noNewline
	} elseif ($Num -ge 0.5) {
		Write-Host  -noNewline
	} elseif ($Num -ge 0.375) {
		Write-Host  -noNewline
	} elseif ($Num -ge 0.25) {
		Write-Host  -noNewline
	} elseif ($Num -ge 0.125) {
		Write-Host  -noNewline
	}
	Write-Host 
}

try {
	Write-Progress 
	$prices = (Invoke-WebRequest -URI  -userAgent  -useBasicParsing).Content | ConvertFrom-Json
	Write-Progress -completed 

	
	
	
	foreach($item in $prices.data) {
		if ($Item.value -eq ) { continue }
		Write-Host  -noNewline
		[int]$value = $Item.value
		WriteHorizontalBar $value 350.0
	}
	exit 0 # success
} catch {
	
	exit 1
}
