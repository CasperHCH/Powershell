<#
.SYNOPSIS
	Speaks text in Greek
.DESCRIPTION
	This PowerShell script speaks the given text with a Greek text-to-speech (TTS) voice.
.PARAMETER text
	Specifies the Greek text to speak
.EXAMPLE
	PS> ./speak-greek.ps1 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$text = )

try {
	if ($text -eq ) { $text = Read-Host  }

	$TTS = New-Object -ComObject SAPI.SPVoice
	foreach ($Voice in $TTS.GetVoices()) {
		if ($Voice.GetDescription() -like ) { 
			$TTS.Voice = $Voice
			[void]$TTS.Speak($text)
			exit 0 # success
		}
	}
	throw 
} catch {
	
	exit 1
}
