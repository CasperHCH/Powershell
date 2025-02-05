<#
.SYNOPSIS
	Writes a chart
.DESCRIPTION
	This PowerShell script writes an horizontal chart to the console.
.EXAMPLE
	PS> ./write-chart.ps1
	
	2023 BOWLING RESULTS
	████████████████▏ 40.5% Joe
	████████████▎ 30.9% Tom
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


	if ($Num -ge 0.875) {
		Write-Host -noNewLine 
	} elseif ($Num -ge 0.75) {
		Write-Host -noNewLine 
	} elseif ($Num -ge 0.625) {
		Write-Host -noNewLine 
	} elseif ($Num -ge 0.5) {
		Write-Host -noNewLine 
	} elseif ($Num -ge 0.375) {
		Write-Host -noNewLine 
	} elseif ($Num -ge 0.25) {
		Write-Host -noNewLine 
	} elseif ($Num -ge 0.125) {
		Write-Host -noNewLine 
	}
	if ($Max -eq 100.0) {
		Write-Host 
	} else {
		Write-Host 
	}
}

Write-Host  -foregroundColor green
WriteChartLine  40.5 100.0
WriteChartLine  30.9 100.0
exit 0 # success
