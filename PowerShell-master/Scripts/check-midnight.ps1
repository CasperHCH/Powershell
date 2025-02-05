<#
.SYNOPSIS
	Checks for Midnight
.DESCRIPTION
	This PowerShell script checks the time until Midnight and replies by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-midnight
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

 elseif ($Delta.Hours -gt 1) { $Result += 
	}
	if ($Delta.Minutes -eq 1) { $Result += 
	} else {                    $Result += 
	}
	return $Result
}

try {
	$Now = [DateTime]::Now
	if ($Now.Hour -lt 12) {
		$Midnight = Get-Date -Hour 0 -Minute 0 -Second 0
		$TimeSpan = TimeSpanToString($Now - $Midnight)
		$Reply = 
	} else {
		$Midnight = Get-Date -Hour 23 -Minute 59 -Second 59
		$TimeSpan = TimeSpanToString($Midnight - $Now)
		$Reply = 
	}
	&  
	exit 0 # success
} catch {
	
	exit 1
}
