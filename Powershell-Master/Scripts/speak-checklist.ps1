<#
.SYNOPSIS
	Speaks a checklist by text-to-speech
.DESCRIPTION
	This PowerShell script speaks the given checklist by text-to-speech (TTS).
.PARAMETER Name
	Specifies the name of the checklist
.EXAMPLE
	PS> ./speak-checklist.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Name = )

try {
	if ($Name -eq ) { $Name = Read-Host  }

	$Lines = Get-Content -path 
	clear-host
	$Step = 1
	foreach($Line in $Lines) {
		if ($Line -like ) { &  ; continue }

					
		&  
		$Dummy = Read-Host 
		$Step++
	}
	exit 0 # success
} catch {
	
	exit 1
}
