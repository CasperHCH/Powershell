<#
.SYNOPSIS
	Lists the Windows Defender settings
.DESCRIPTION
	This PowerShell script lists the current settings of Windows Defender Antivirus.
	NOTE: use 'Set-MpPreference' to change settings (e.g. DisableScanningNetworkFiles)
.EXAMPLE
	PS> ./list-defender-settings.ps1

	AttackSurfaceReductionOnlyExclusions          :
	CheckForSignaturesBeforeRunningScan           : False
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Write-Host 
	Write-Host  -noNewline
	Get-MpPreference
	
	exit 0 # success
} catch {
	
	exit 1
}
