<#
.SYNOPSIS
	Creates a new Git branch 
.DESCRIPTION
	This PowerShell script creates a new branch in a local Git repository and switches to it.
.PARAMETER newBranch
	Specifies the new branch name
.PARAMETER repoPath
	Specifies the path to the Git repository (current working directory per default)
.EXAMPLE
	PS> ./new-branch.ps1 test123 C:\MyRepo
	⏳ (1/6) Searching for Git executable...  git version 2.42.0.windows.2
	⏳ (2/6) Checking local repository...
	⏳ (3/6) Fetching latest updates...
	⏳ (4/6) Creating new branch...
	⏳ (5/6) Pushing updates...
	⏳ (6/6) Updating submodules...
	✔️ Created branch 'test123' in repo 📂MyRepo (based on 'main' in 18 sec)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$newBranch = , [string]$repoPath = )

try {
	if ($newBranch -eq ) { $newBranch = Read-Host  }

	$stopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -noNewline
	& git --version
	if ($lastExitCode -ne ) { throw  }

	Write-Host 
	if (-not(Test-Path  -pathType container)) { throw  }
	$repoPathName = (Get-Item ).Name

	
	& git -C  fetch --all --recurse-submodules --prune --prune-tags --force
	if ($lastExitCode -ne ) { throw  }

	$currentBranch = (git -C  rev-parse --abbrev-ref HEAD)
	if ($lastExitCode -ne ) { throw  }

	
	& git -C  checkout -b 
	if ($lastExitCode -ne ) { throw  }

	
	& git -C  push origin 
	if ($lastExitCode -ne ) { throw  }

	
	& git -C  submodule update --init --recursive
	if ($lastExitCode -ne ) { throw  }

	[int]$elapsed = $stopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
