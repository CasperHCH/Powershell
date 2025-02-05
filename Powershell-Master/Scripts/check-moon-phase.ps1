<#
.SYNOPSIS
	Checks the Moon phase
.DESCRIPTION
	This PowerShell script determines the Moon phase and answers by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-moon-phase
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$LunarCycle = 29.53058868 # synodic period in days, time between successive new moons
	$LunarHalfCycle = $LunarCycle / 2.0
	$Phases = @(, , , , , , , )
	$PhaseLength = $LunarCycle / 8.0
	$PhaseHalfLength = $PhaseLength / 2.0

	$RefDate = get-date -Year 2021 -Month 12 -Day 4 -Hour 6 -Minute 43 # Dec 4, 2021 06:43 UTC [New Moon]
	$Now = get-date
	$TimeInterval = New-TimeSpan -Start $RefDate -End $Now
	$Days = $TimeInterval.TotalDays

	$MDays = $Days % $LunarCycle
	$PhaseIndex = [int]($MDays * (8.0 / $LunarCycle))

	$Visibility = [math]::Round((($Days % $LunarHalfCycle) * 100) / $LunarHalfCycle)
	$Reply = 

	$MoonAge = [math]::Round($Days % $LunarCycle)	
	if ($MoonAge -eq ) {	      $Reply += 
	} elseif ($MoonAge -eq ) { $Reply += 
	} else {                      $Reply += 
	}

	&  
	exit 0 # success
} catch {
	
	exit 1
}
