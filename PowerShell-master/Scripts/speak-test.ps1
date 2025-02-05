<#
.SYNOPSIS
	Performs a text-to-speech test
.DESCRIPTION
	This PowerShell script performs a text-to-speech (TTS) test.
.EXAMPLE
	PS> ./speak-test.ps1
	📣 Let's begin with the default speed rate of 0 at the default volume of 100%.
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

function Speak([string]$Text) { 
	Write-Output 
	[void]$Voice.speak()
}

try {
	$Voice = New-Object -ComObject SAPI.SPVoice
	$DefaultVolume = $Voice.volume
	$DefaultRate = $Voice.rate
	Speak()

	$Voice.rate = -10
	Speak()
	$Voice.rate = -5
	Speak()
	$Voice.rate = -3
	Speak()
	$Voice.rate = 0
	Speak()
	$Voice.rate = 2
	Speak()
	$Voice.rate = 5
	Speak()
	$Voice.rate = 10
	Speak()
	$Voice.rate = $DefaultRate

	$Voice.volume = 100
	Speak()
	$Voice.volume = 75
	Speak()
	$Voice.volume = 50
	Speak()
	$Voice.volume = 25
	Speak()
	$Voice.volume = $DefaultVolume

	$Voices = $Voice.GetVoices()
	foreach ($OtherVoice in $Voices) {
		$Voice.Voice = $OtherVoice
		$Description = $OtherVoice.GetDescription()
		Speak()
	}
	Speak()
	exit 0 # success
} catch {
	
	exit 1
}
