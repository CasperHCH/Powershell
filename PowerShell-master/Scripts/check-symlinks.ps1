<#
.SYNOPSIS
	Checks symlinks in a folder
.DESCRIPTION
	This PowerShell script checks every symbolic link in a folder (including subfolders).
	It returns the number of broken symlinks as exit value.
.PARAMETER folder
	Specifies the path to the folder
.EXAMPLE
	PS> ./check-symlinks C:\Users
	⏳ Checking symlinks at 📂C:\Users including subfolders...
	✔️ Found 0 broken symlinks at 📂C:\Users in 60 sec
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Folder = )

try {
	if ($Folder -eq  ) { $Folder = read-host  }

	$StopWatch = [system.diagnostics.stopwatch]::startNew()
	$FullPath = Resolve-Path 
	

	[int]$NumTotal = [int]$NumBroken = 0
	Get-ChildItem $FullPath -recurse  | Where { $_.Attributes -match  } | ForEach-Object {
		$Symlink = $_.FullName
		$Target = ($_ | Select-Object -ExpandProperty Target -ErrorAction Ignore)
		if ($Target) {
			$path = $_.FullName +  + ($_ | Select-Object -ExpandProperty Target)
			$item = Get-Item $path -ErrorAction Ignore
			if (!$item) {
				$NumBroken++
				
			}
		}
		$NumTotal++
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	if ($NumTotal -eq 0) {
		 
	} elseif ($NumBroken -eq 1) {
		
	} else {
		
	}
	exit $NumBroken
} catch {
	
	exit 1
}
