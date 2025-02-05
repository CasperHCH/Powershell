<#
.SYNOPSIS
	Launches the Firefox browser
.DESCRIPTION
	This PowerShell script launches the Mozilla Firefox Web browser.
.EXAMPLE
	PS> ./open-firefox
.PARAMETER URL
	Specifies an URL
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$URL = )

try {
	$App = Get-AppxPackage -Name Mozilla.FireFox
	if ($App.Status -eq ) {
		# starting Firefox UWP app:
		explorer.exe shell:appsFolder\$($App.PackageFamilyName)!FIREFOX
	} else {
		# starting Firefox program:
		start-process firefox.exe 
	}
	exit 0 # success
} catch {
	
	exit 1
}
