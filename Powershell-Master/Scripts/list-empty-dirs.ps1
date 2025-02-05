<#
.SYNOPSIS
	Lists empty subfolders
.DESCRIPTION
	This PowerShell script scans and lists all empty subfolders within the given directory tree.
.PARAMETER DirTree
	Specifies the path to the directory tree (current working directory by default)
.EXAMPLE
	PS> ./list-empty-dirs.ps1 C:\
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$DirTree = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	$DirTree = Resolve-Path 
	Write-Progress 
	[int]$Count = 0
	Get-ChildItem  -attributes Directory -recurse | Where {$_.GetFileSystemInfos().Count -eq 0} | ForEach-Object {
		
		$Count++
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	 
	exit 0 # success
} catch {
	
	exit 1
}
