<#
.SYNOPSIS
	Pulls updates into Git repos
.DESCRIPTION
	This PowerShell script pulls updates into all Git repositories in a folder (including submodules).
.PARAMETER ParentDir
	Specifies the path to the parent folder
.EXAMPLE
	PS> ./pull-repos C:\MyRepos
	⏳ (1) Searching for Git executable...  git version 2.41.0.windows.3
	⏳ (2) Checking parent folder...        33 subfolders
	⏳ (3/35) Pulling into 📂base256unicode...
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$ParentDir = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -NoNewline
	& git --version
	if ($lastExitCode -ne ) { throw  }

	Write-Host  -NoNewline
	if (-not(Test-Path  -pathType container)) { throw  }
	$Folders = (Get-ChildItem  -attributes Directory)
	$NumFolders = $Folders.Count
	$ParentDirName = (Get-Item ).Name
	Write-Host 

	[int]$Step = 3
	[int]$Failed = 0
	foreach ($Folder in $Folders) {
		$FolderName = (Get-Item ).Name
		Write-Host  -NoNewline

		& git -C  pull --recurse-submodules --jobs=4
		if ($lastExitCode -ne ) { $Failed++; write-warning  }

		& git -C  submodule update --init --recursive
		if ($lastExitCode -ne ) { throw  }
		$Step++
	}
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
