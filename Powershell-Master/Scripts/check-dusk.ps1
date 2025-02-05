<#
.SYNOPSIS
	Checks the time of dusk 
.DESCRIPTION
	This PowerShell script queries the time of dusk and answers by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-dusk.ps1
	Dusk is in 2 hours at 8 PM.
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
	[system.threading.thread]::currentThread.currentCulture=[system.globalization.cultureInfo]
	$String = (Invoke-WebRequest http://wttr.in/?format= -UserAgent  -useBasicParsing).Content
	$Hour,$Minute,$Second = $String -split ':'
	$Dusk = Get-Date -Hour $Hour -Minute $Minute -Second $Second
	$Now = [DateTime]::Now
	if ($Now -lt $Dusk) {
                $TimeSpan = TimeSpanToString($Dusk - $Now)
                $Reply = 
        } else {
                $TimeSpan = TimeSpanToString($Now - $Dusk)
                $Reply = 
        }
	Write-Output $Reply
	exit 0 # success
} catch {
	
	exit 1
}
