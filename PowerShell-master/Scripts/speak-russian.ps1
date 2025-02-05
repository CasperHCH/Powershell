<#
.SYNOPSIS
	Speaks text in Russian
.DESCRIPTION
	This PowerShell script speaks the text with a Russian text-to-speech (TTS) voice.
.PARAMETER text
	Specifies the Russian text
.EXAMPLE
	PS> ./speak-russian.ps1 
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
			[void]$TTS.Speak()
			exit 0 # success
		}
	}
	throw 
} catch {
	
	exit 1
}
