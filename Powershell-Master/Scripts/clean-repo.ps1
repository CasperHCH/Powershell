<#
.SYNOPSIS
	Cleans a repo
.DESCRIPTION
	This PowerShell script deletes all untracked files and folders in a local Git repository (including submodules).
	NOTE: To be used with care! This cannot be undone!
.PARAMETER RepoDir
	Specifies the file path to the local Git repository
.EXAMPLE
	PS> ./clean-repo.ps1 C:\rust
	⏳ (1/4) Searching for Git executable...          git version 2.41.0.windows.3
	⏳ (2/4) Checking local repository...        	  📂C:\rust
	⏳ (3/4) Removing untracked files in repository...
	⏳ (4/4) Removing untracked files in submodules...
	✔️ Cleaned repo 📂rust in 1 sec
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RepoDir = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -noNewline
	& git --version
	if ($lastExitCode -ne ) { throw  }

	
	if (-not(Test-Path  -pathType container)) { throw  }
	$RepoDirName = (Get-Item ).Name

	
	& git -C  clean -xfd -f # to delete all untracked files in the main repo
	if ($lastExitCode -ne ) {
		Write-Warning 
		& git -C  clean -xfd -f 
		if ($lastExitCode -ne ) { throw  }
	}

	
	& git -C  submodule foreach --recursive git clean -xfd -f # to delete all untracked files in the submodules
	if ($lastExitCode -ne ) { throw  }

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
