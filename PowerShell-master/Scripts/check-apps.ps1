<#
.SYNOPSIS
	Query the app status
.DESCRIPTION
	This PowerShell script queries the installed applications and prints it.
.EXAMPLE
	PS> ./check-apps.ps1
	✅ 119 Windows apps installed, 11 upgrades available
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		Write-Progress 
		$numPkgs = (apt list --installed 2>/dev/null).Count
		$numSnaps = (snap list).Count - 1
		Write-Progress -Completed 
		Write-Host 
	} else {
		Write-Progress 
		$Apps = Get-AppxPackage
		Write-Progress -Completed 
		Write-Host  -noNewline

		[int]$NumNonOk = 0
		foreach($App in $Apps) { if ($App.Status -ne ) { $NumNonOk++ } }
		if ($NumNonOk -gt 0) { $Status +=  }
		[int]$NumErrors = (Get-AppxLastError)
		if ($NumErrors -gt 0) { $Status +=  }

		$NumUpdates = (winget upgrade --include-unknown).Count - 5
		Write-Host 
	}
	exit 0 # success
} catch {
	
	exit 1
}
