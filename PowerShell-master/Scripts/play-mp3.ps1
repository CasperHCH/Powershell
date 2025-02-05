<#
.SYNOPSIS
	Plays a MP3 sound file 
.DESCRIPTION
	This PowerShell script plays a sound file in .MP3 file format.
.PARAMETER Path
	Specifies the path to the .MP3 file
.EXAMPLE
	PS> ./play-mp3 C:\thunder.mp3
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Path = )

try {
	if ($Path -eq  ) { $Path = Read-Host  }

	if (-not(Test-Path  -pathType leaf)) { throw  }
	$FullPath = (Get-ChildItem $Path).fullname
	$Filename = (Get-Item ).name

	Add-Type -assemblyName PresentationCore
	$MediaPlayer = New-Object System.Windows.Media.MediaPlayer

	do {
		$MediaPlayer.open($FullPath)
		$Milliseconds = $MediaPlayer.NaturalDuration.TimeSpan.TotalMilliseconds
	} until ($Milliseconds)

	[int]$Minutes = $Milliseconds / 60000
	[int]$Seconds = ($Milliseconds / 1000) % 60
	
	$PreviousTitle = $host.ui.RawUI.WindowTitle 
	$host.ui.RawUI.WindowTitle = 
	$MediaPlayer.Volume = 1
	$MediaPlayer.play()
	Start-Sleep -milliseconds $Milliseconds
	$MediaPlayer.stop()
	$MediaPlayer.close()
	$host.ui.RawUI.WindowTitle = $PreviousTitle

	exit 0 # success
} catch {
	
	exit 1
}
