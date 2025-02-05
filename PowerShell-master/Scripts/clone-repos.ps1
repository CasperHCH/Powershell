<#
.SYNOPSIS
	Clones Git repos
.DESCRIPTION
	This PowerShell script clones popular Git repositories into a target directory.
.PARAMETER targetDir
	Specifies the file path to the target directory (current working directory by default)
.EXAMPLE
	PS> ./clone-repos C:\Repos
	⏳ (1) Searching for Git executable...          git version 2.41.0.windows.3
	⏳ (2) Reading Data/popular-repositories.csv... 28 repos
	⏳ (3) Checking target folder...                📂repos
	⏳ (4/32) Cloning into 📂base256unicode (dev tool)...
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$TargetDir = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -noNewline
	& git --version
	if ($lastExitCode -ne ) { throw  }

	Write-Host  -noNewline
	$Table = Import-CSV 
	$NumEntries = $Table.count
	Write-Host 

	$TargetDirName = (Get-Item ).Name
	Write-Host 
	if (-not(Test-Path  -pathType container)) { throw  }
	
	[int]$Step = 3
	[int]$Cloned = 0
	[int]$Skipped = 0
	foreach($Row in $Table) {
		[string]$FolderName = $Row.FOLDERNAME
		[string]$Category = $Row.CATEGORY
		[string]$Branch = $Row.BRANCH
		[string]$Shallow = $Row.SHALLOW
		[string]$URL = $Row.URL
		$Step++

		if (Test-Path  -pathType container) {
			
			$Skipped++
			continue
		}
		if ($Shallow -eq ) {
			
			& git clone --branch  --single-branch --recurse-submodules  
			if ($lastExitCode -ne ) { throw  }
		} else {
			
			& git clone --branch  --recurse-submodules  
			if ($lastExitCode -ne ) { throw  }
		}
		$Cloned++
	}
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
