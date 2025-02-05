<#
.SYNOPSIS
	Creates a new .ZIP file from a folder (including subfolders)
.DESCRIPTION
	This PowerShell script creates a new .ZIP file from a folder (including subfolders).
.PARAMETER folder
	Specifies the path to the folder
.EXAMPLE
	PS> ./new-zipfile.ps1 C:\Windows
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$folder = )

try {
	if ($folder -eq  ) { $folder = read-host  }
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	$folder = resolve-path $folder
	compress-archive -path $folder -destinationPath $folder.zip

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
