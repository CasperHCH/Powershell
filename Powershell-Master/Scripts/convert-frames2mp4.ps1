<#
.SYNOPSIS
	Converts frames to a .MP4 video
.DESCRIPTION
	This PowerShell script converts multiple image frames into a video in MP4 format. It requires ffmpeg.
.PARAMETER SourcePattern
	Specifies the file pattern of the image frames
.PARAMTER TargetFile
	Specifies the path to the new video file.
.EXAMPLE
	PS> ./convert-frames2mp4 C:\Frames\*.jpg C:\video.mp4
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$SourcePattern = , [string]$TargetFile = )

try {
	if ($SourcePattern -eq ) { $SourcePattern = Read-Host  }
	if ($TargetFile -eq ) { $TargetFile = Read-Host  }
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	
	& ffmpeg -L
	if ($lastExitCode -ne ) { throw  }

	
	$Files = (Get-ChildItem -path  -attributes !Directory)

	
	& ffmpeg -framerate 24 -pattern_type glob -i  -c:v libx264 -pix_fmt yuv420p 

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
