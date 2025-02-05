<#
.SYNOPSIS
	Pulls updates into a Git repository
.DESCRIPTION
	This PowerShell script pulls the latest updates into a local Git repository (including submodules).
.PARAMETER RepoDir
	Specifies the file path to the local Git repository (default is working directory)
.EXAMPLE
	PS> ./pull-repo.ps1 C:\MyRepo
	⏳ (1/4) Searching for Git executable...  git version 2.42.0.windows.1
	⏳ (2/4) Checking local repository...
	⏳ (3/4) Pulling updates...
	⏳ (4/4) Updating submodules...
	✔️ Pulled updates into repo 📂MyRepo in 14 sec
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

	Write-Host 
	if (-not(Test-Path  -pathType container)) { throw  }
	$Result = (git -C  status)
	if ( -match ) { throw  }
	$RepoDirName = (Get-Item ).Name

	Write-Host 
	& git -C  pull --recurse-submodules=yes
	if ($lastExitCode -ne ) { throw  }

	Write-Host 
	& git -C  submodule update --init --recursive
	if ($lastExitCode -ne ) { throw  }

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
