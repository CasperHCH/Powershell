<#
.SYNOPSIS
	Speaks file content by text-to-speech
.DESCRIPTION
	This PowerShell script speaks the content of the given text file by text-to-speech (TTS).
.PARAMETER File
	Specifies the path to the text file
.EXAMPLE
	PS> ./speak-file.ps1 C:\MyFile.txt
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$File = )

try {
	if ($File -eq ) { $File = Read-Host  }

	$Text = Get-Content $File

	$Voice = new-object -ComObject SAPI.SPVoice
	$Result = $Voice.Speak($Text)
	exit 0 # success
} catch {
	
	exit 1
}
