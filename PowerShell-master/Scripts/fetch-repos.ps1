<#
.SYNOPSIS
	Fetches updates into Git repos
.DESCRIPTION
	This PowerShell script fetches updates into all Git repositories in a folder (including submodules).
.PARAMETER ParentDir
	Specifies the path to the parent folder
.EXAMPLE
	PS> ./fetch-repos.ps1 C:\MyRepos
	⏳ (1) Searching for Git executable...  git version 2.41.0.windows.3
	⏳ (2) Checking parent folder...        33 subfolders
	⏳ (3/35) Fetching into 📂base256unicode...
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$parentDirPath = )

try {
	$stopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -noNewline
	& git --version
	if ($lastExitCode -ne ) { throw  }

	Write-Host  -noNewline
	if (-not(Test-Path  -pathType container)) { throw  }
	$folders = (Get-ChildItem  -attributes Directory)
	$numFolders = $folders.Count
	$parentDirPathName = (Get-Item ).Name
	Write-Host 

	[int]$step = 3
	foreach ($folder in $folders) {
		$folderName = (Get-Item ).Name
		Write-Host 

		& git -C  fetch --all --recurse-submodules --prune --prune-tags --force
		if ($lastExitCode -ne ) { throw  }

		$step++
	}
	[int]$elapsed = $stopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
