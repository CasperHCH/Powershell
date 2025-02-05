<#
.SYNOPSIS
	Removes old directories
.DESCRIPTION
	This PowerShell script removes any subfolder in a parent folder older than <numDays> (using last write time).
.PARAMETER path
	Specifies the file path to the parent folder
.PARAMETER numDays
	Specifies the number of days (1000 by default)
.EXAMPLE
	PS> ./remove-old-dirs.ps1 C:\Temp 90
.NOTES
	Author: Markus Fleschutz
#>

param([string]$path = , [int]$numDays = 1000)

try {
	$stopWatch = [system.diagnostics.stopwatch]::startNew()
	if ( -eq ) { $path = Read-Host  }
	if (!(Test-Path -Path  -PathType container)) { throw  }

	Write-Host 
	$folders = Get-ChildItem -path  -directory
	$numRemoved = 0
	$count = 0
	foreach ($folder in $folders) {
		[datetime]$folderDate = ($folder | Get-ItemProperty -Name LastWriteTime).LastWriteTime
		$count++
		if ($folderDate -lt (Get-Date).AddDays(-$numDays)) {
			Write-Host 
			$fullPath = $folder | Select-Object -ExpandProperty FullName
			Remove-Item -path  -force -recurse
			$numRemoved++
		} else {
			Write-Host 
		}
	}
	[int]$elapsed = $stopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
