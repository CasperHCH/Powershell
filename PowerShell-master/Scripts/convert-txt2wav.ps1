<#
.SYNOPSIS
	Converts text to a .WAV audio file
.DESCRIPTION
	This PowerShell script converts text to a .WAV audio file.
.PARAMETER text
	Specifies the text to use
.PARAMETER WavFile
	Specifies the path to the resulting WAV file
.EXAMPLE
	PS> ./convert-txt2wav.ps1  spoken.wav
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Text = , [string]$WavFile = )

try {
	if ($Text -eq ) { $Text = read-host  }
	if ($WavFile -eq ) { $WavFile = read-host  }

	Add-Type -AssemblyName System.Speech
	$SpeechSynthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer
	$SpeechSynthesizer.SetOutputToWaveFile($WavFile)
	$SpeechSynthesizer.Speak($Text)
	$SpeechSynthesizer.Dispose()
	exit 0 # success
} catch {
	
	exit 1
}
