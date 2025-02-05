<#
.SYNOPSIS
	Plays a playlist (.M3U format)
.DESCRIPTION
	This PowerShell script plays the given playlist (in .M3U file format)
.PARAMETER filename
	Specifies the path to the playlist
.EXAMPLE
	PS> ./play-m3u C:\MyPlaylist.m3u
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$filename = )

try {
	if ($filename -eq  ) { $filename = read-host  }

	if (-not(test-path  -pathType leaf)) { throw  }
	$Lines = get-content $filename

	add-type -assemblyName presentationCore
	$MediaPlayer = new-object system.windows.media.mediaplayer

	for ([int]$i=0; $i -lt $Lines.Count; $i++) {
		$Line = $Lines[$i]
		if ($Line[0] -eq ) { continue }
		if (-not(test-path  -pathType leaf)) { throw  }
		$FullPath = (get-childItem ).fullname
		$filename = (get-item ).name
		do {
			$MediaPlayer.open()
			$Milliseconds = $MediaPlayer.NaturalDuration.TimeSpan.TotalMilliseconds
		} until ($Milliseconds)
		[int]$Minutes = $Milliseconds / 60000
		[int]$Seconds = ($Milliseconds / 1000) % 60
		
		$MediaPlayer.Volume = 1
		$MediaPlayer.play()
		start-sleep -milliseconds $Milliseconds
		$MediaPlayer.stop()
		$MediaPlayer.close()
	}
	exit 0 # success
} catch {
	
	exit 1
}
