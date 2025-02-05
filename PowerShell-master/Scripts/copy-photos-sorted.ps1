<#
.SYNOPSIS
	Copy photos sorted by year and month
.DESCRIPTION
	This PowerShell script copies image files from sourceDir to targetDir sorted by year and month.
.PARAMETER sourceDir
	Specifies the path to the source folder
.PARAMTER targetDir
	Specifies the path to the target folder
.EXAMPLE
	PS> ./copy-photos-sorted.ps1 D:\iPhone\DCIM C:\MyPhotos
	⏳ Copying IMG_20230903_134445.jpg to C:\MyPhotos\2023\09 SEP\...
	✔️ Copied 1 photo to 📂C:\MyPhotos in 41 sec
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$sourceDir = , [string]$targetDir = )


	2  {}
	3  {}
	4  {}
	5  {}
	6  {}
	7  {}
	8  {}
	9  {}
	10 {}
	11 {}
	12 {}
	}
	$TargetPath = 
	if (Test-Path  -pathType leaf) {
		Write-Host 
	} else {
		Write-Host 
		New-Item -path  -name  -itemType  -force | out-null
		New-Item -path  -name  -itemType  -force | out-null
		Copy-Item   -force
	}
}

try {
	if ($sourceDir -eq ) { $sourceDir = Read-Host  }
	if ($targetDir -eq ) { $targetDir = Read-Host  }
	$stopWatch = [system.diagnostics.stopWatch]::startNew()

	Write-Host 
	if (-not(Test-Path  -pathType container)) { throw  }
	$files = (Get-ChildItem  -attributes !Directory)

	Write-Host 
	if (-not(Test-Path  -pathType container)) { throw  }

	foreach($file in $files) {
		$filename = (Get-Item ).Name
		if ( -like ) {
			$Array = $filename.split()
			CopyFile   $Array[1] 
		} elseif ( -like ) {
			$Array = $filename.split()
			CopyFile   $Array[1] 
		} elseif ( -like ) {
			$Array = $filename.split()
			CopyFile    $Array[1] 
		} elseif ( -like ) {
			$Array = $filename.split()
			CopyFile   $Array[1] 
		} elseif ( -like ) {
			$Array = $filename.split()
			CopyFile   $Array[1] 
		} else {
			Write-Host 
		}
	}
	[int]$elapsed = $stopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
