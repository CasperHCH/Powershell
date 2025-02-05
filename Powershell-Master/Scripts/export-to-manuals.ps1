<#
.SYNOPSIS
	Exports all scripts as manuals
.DESCRIPTION
	This PowerShell script exports the comment based help of all PowerShell scripts as manuals.
.EXAMPLE
	PS> ./export-to-manuals.ps1
	⏳ (1/2) Reading PowerShell scripts from /home/mf/PowerShell/Scripts/*.ps1 ... 
	⏳ (2/2) Exporting Markdown manuals to /home/mf/PowerShell/Scripts/../Docs ...
	✔️ Exported 518 Markdown manuals in 28 sec
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#requires -version 2

param([string]$FilePattern = , [string]$TargetDir = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	 
	$Scripts = Get-ChildItem 

	
	foreach ($Script in $Scripts) {
		&   > 
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
