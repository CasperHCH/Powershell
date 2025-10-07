<#
.SYNOPSIS
	Counts the lines of code (LOC)
.DESCRIPTION
	This PowerShell script counts the number of code lines in a directory tree.
.PARAMETER path
	Specifies the path to the directory tree.
.EXAMPLE
	PS> ./count-lines-of-code.ps1 .
	✔️ 19765 lines of code (LOC) in 578 files in 📂Scripts (it took 1 sec)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$path = )

try {
	if ($path -eq  ) { $path = Read-Host  }

	$stopWatch = [system.diagnostics.stopwatch]::startNew()
	$path = Resolve-Path 

	Write-Progress 
	[int]$files = [int]$LOC = 0
	Get-ChildItem -Path $path -Include *.c,*.h,*.cpp,*.hpp,*.java,*.ps1 -Recurse | ForEach-Object {
		$fileStats = Get-Content $_.FullName | Measure-Object -line
		$LOC += $fileStats.Lines
		$files++
	}
	Write-Progress -completed 

	$folderName = (Get-Item ).Name
	[int]$Elapsed = $stopWatch.Elapsed.TotalSeconds
	 
	exit 0 # success
} catch {
	
	exit 1
}
