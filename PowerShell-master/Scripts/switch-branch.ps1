<#
.SYNOPSIS
	Switches the Git branch
.DESCRIPTION
	This PowerShell script switches to another branch in a Git repository (including submodules).
.PARAMETER branchName
	Specifies the branch name
.PARAMETER repoDir
	Specifies the path to the local Git repository
.EXAMPLE
	PS> ./switch-branch main C:\MyRepo
	⏳ (1/6) Searching for Git executable...   git version 2.42.0.windows.1
	⏳ (2/6) Checking local repository...
	⏳ (3/6) Fetching updates...
	⏳ (4/6) Switching to branch 'main'...
	⏳ (5/6) Pulling updates...
	⏳ (6/6) Updating submodules...
	✔️ Switched repo 📂MyRepo to branch 'main' in 22 sec
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$branchName = , [string]$repoDir = )

try {
	if ($branchName -eq ) { $branchName = Read-Host  }
	if ($repoDir -eq ) { $repoDir = Read-Host  }

	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -noNewline
	& git --version
	if ($lastExitCode -ne ) { throw  }

	Write-Host 
	$repoDir = Resolve-Path 
	if (-not(Test-Path  -pathType container)) { throw  }
	$Result = (git status)
	if ($lastExitCode -ne ) { throw  }
	if ( -notmatch ) { throw  }
	$repoDirName = (Get-Item ).Name

	
	& git -C  fetch --all --prune --prune-tags --force
	if ($lastExitCode -ne ) { throw  }

	
	& git -C  checkout --recurse-submodules 
	if ($lastExitCode -ne ) { throw  }

	
	& git -C  pull --recurse-submodules
	if ($lastExitCode -ne ) { throw  }

		
	& git -C  submodule update --init --recursive
	if ($lastExitCode -ne ) { throw  }

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
