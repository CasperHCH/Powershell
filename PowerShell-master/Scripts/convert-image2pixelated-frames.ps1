<#
.SYNOPSIS
	Converts an image into pixelated frames
.DESCRIPTION
	This PowerShell script converts a single image file into a series of pixelated frames in a target dir.
	Requires ImageMagick 6.
.PARAMETER SourceFile
	Specifies the path to the image source file
.PARAMTER TargetDir
	Specifies the path to the target folder
.EXAMPLE
	PS> ./convert-image2pixelated-frames C:\my_photo.jpg C:\Temp
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$SourceFile = , [string]$TargetDir = , [int]$Frames = 700)

try {
	if ($SourceFile -eq ) { $SourceFile = Read-Host  }
	if ($TargetDir -eq ) { $TargetDir = Read-Host  }
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	
	if (!(Test-Path  -pathType leaf)) { throw  }
	$Basename = (Get-Item ).Basename

	
	& convert-im6 --version
	if ($lastExitCode -ne ) { throw  }

	$Factor = 0.001
	for ($i = 0; $i -lt $Frames; $i++) {
		$FrameNo = '{0:d4}' -f $i
		$TargetFile = 
		
		$Coeff1 = 100.0 * $Factor
		$Coeff2 = 100.0 / $Factor
		& convert-im6 -scale $Coeff1% -scale $Coeff2%  
		$Factor += 0.0005
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
