<#
.SYNOPSIS
	Builds Git repositories
.DESCRIPTION
	This PowerShell script builds all Git repositories in a folder.
.PARAMETER ParentDir
	Specifies the path to the parent folder
.EXAMPLE
	PS> ./build-repos.ps1 C:\MyRepos
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$ParentDir = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	$ParentDirName = (Get-Item ).Name
	
	if (-not(Test-Path  -pathType container)) { throw  }
	$Folders = (Get-ChildItem  -attributes Directory)
	$FolderCount = $Folders.Count
	

	[int]$Step = 1
	foreach ($Folder in $Folders) {
		&  
		$Step++
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
