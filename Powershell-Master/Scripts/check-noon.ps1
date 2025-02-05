<#
.SYNOPSIS
	Checks for Noon
.DESCRIPTION
	This PowerShell script checks the time until Noon and replies by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-noon
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
	$Noon = Get-Date -Hour 12 -Minute 0 -Second 0
	if ($Now -lt $Noon) {
		$TimeSpan = TimeSpanToString($Noon - $Now)
		$Reply = 
	} else {
		$TimeSpan = TimeSpanToString($Now - $Noon)
		$Reply = 
	}
	&  
	exit 0 # success
} catch {
	
	exit 1
}
