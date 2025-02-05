<#
.SYNOPSIS
	Speaks text in Norwegian
.DESCRIPTION
	This PowerShell script speaks the given text with a Norwegian text-to-speech (TTS) voice.
.PARAMETER text
	Specifies the Norwegian text to speak
.EXAMPLE
	PS> ./speak-norwegian.ps1 Hallo
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
