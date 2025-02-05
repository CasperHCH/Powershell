<#
.SYNOPSIS
	Plays audio files (MP3 and WAV)
.DESCRIPTION
	This PowerShell script plays the given audio files (supporting MP3 and WAV format).
.PARAMETER FilePattern
	Specifies the file pattern
.EXAMPLE
	PS> ./play-files *.mp3
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$FilePattern = )

try {
	$Files = (get-childItem -path  -attributes !Directory)
	
	foreach ($File in $Files) {
		if ( -like ) {
			&  
		} elseif ( -like ) {
			&  
		} else {
			
		}
	}
	exit 0 # success
} catch {
	
	exit 1
}
