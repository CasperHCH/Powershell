<#
.SYNOPSIS
	Converts an image into blurred frames
.DESCRIPTION
	This PowerShell script converts a single image file into a series of blurred frames in a target dir.
	Requires ImageMagick 6.
.PARAMETER ImageFile
	Specifies the path to the image file
.PARAMTER TargetDir
	Specifies the path to the target folder
.EXAMPLE
	PS> ./convert-image2blurred-frames C:\photo.jpg C:\Temp
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$ImageFile = , [string]$TargetDir = , [int]$ImageWidth = 1920, [int]$ImageHeight = 1393, [int]$Frames = 600)

try {
	if ($ImageFile -eq ) { $ImageFile = Read-Host  }
	if ($TargetDir -eq ) { $TargetDir = Read-Host  }
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	
	if (!(Test-Path  -pathType leaf)) { throw  }
	$Basename = (Get-Item ).Basename

	
	& convert-im6 --version
	if ($lastExitCode -ne ) { throw  }

	[int]$centerX = $ImageWidth / 2 
	[int]$centerY = $ImageHeight / 2
	[int]$x = 0
	[float]$increment = $centerX / $Frames
	for ($i = 0; $i -lt $Frames; $i++) {
		$FrameNo = '{0:d4}' -f $i
		$TargetFile = 
		
		& convert-im6 -stroke black -strokewidth 9 -fill white -draw   
		$x += $increment
	}
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
