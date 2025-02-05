<#
.SYNOPSIS
	Speaks text in Esperanto
.DESCRIPTION
	This PowerShell script speaks the given text with an Esperanto text-to-speech (TTS) voice.
.PARAMETER text
	Specifies the Esperanto text to speak
.EXAMPLE
	PS> ./speak-esperanto.ps1 Saluton
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
