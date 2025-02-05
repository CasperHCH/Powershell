<#
.SYNOPSIS
	Speaks text in Danish
.DESCRIPTION
	This PowerShell script speaks the given text with a Danish text-to-speech (TTS) voice.
.PARAMETER text
	Specifies the Danish text to speak
.EXAMPLE
	PS> ./speak-danish.ps1 Hej
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
