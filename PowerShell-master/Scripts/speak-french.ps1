<#
.SYNOPSIS
	Speaks text in French
.DESCRIPTION
	This PowerShell script speaks the given text with a French text-to-speech (TTS) voice.
.PARAMETER text
	Specifies the French text to speak
.EXAMPLE
	PS> ./speak-french.ps1 Salut
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$text = )

try {
	if ($text -eq ) { $text = Read-Host  }

	$TTS = New-Object -ComObject SAPI.SPVoice
	foreach ($voice in $TTS.GetVoices()) {
		if ($voice.GetDescription() -like ) {
			$TTS.Voice = $voice
			[void]$TTS.Speak($text)
			exit 0 # success
		}
	}
	throw 
} catch {
	
	exit 1
}
