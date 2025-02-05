<#
.SYNOPSIS
	Checks a repo
.DESCRIPTION
	This PowerShell script verifies the integrity of a local Git repository.
.PARAMETER RepoDir
	Specifies the path to the Git repository (current working directory by default)
.EXAMPLE
	PS> ./check-repo.ps1 C:\MyRepo
	⏳ (1/10) Searching for Git executable...  git version 2.41.0.windows.3
	⏳ (2/10) Checking local folder...         📂C:\MyRepo
	⏳ (3/10) Querying remote URL...           git@github.com:fleschutz/PowerShell.git
	⏳ (4/10) Querying current branch...       main
	⏳ (5/10) Fetching remote updates...
	⏳ (6/10) Querying latest tag...           v0.8 (commit 02171a401d83b01a0cda0af426840b605e617f08)
	⏳ (7/10) Verifying data integrity...
	...
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

	Write-Host  -noNewline
	$FullPath = Resolve-Path 
	if (!(Test-Path  -pathType Container)) { throw  }
	

	Write-Host  -noNewline
	& git -C  remote get-url origin
	if ($lastExitCode -ne ) { throw  }

	Write-Host  -noNewline
	& git -C  branch --show-current
	if ($lastExitCode -ne ) { throw  }

	Write-Host 
	& git -C  fetch
	if ($lastExitCode -ne ) { throw  }

	Write-Host  -noNewline
        $LatestTagCommitID = (git -C  rev-list --tags --max-count=1)
        $LatestTagName = (git -C  describe --tags $LatestTagCommitID)
        Write-Host 
	& git -C  fsck 
	if ($lastExitCode -ne ) { throw  }

	Write-Host 
	& git -C  maintenance run
	if ($lastExitCode -ne ) { throw  }

	Write-Host 
	& git -C  submodule status
	if ($lastExitCode -ne ) { throw  }

	Write-Host  -noNewline
	& git -C  status 
	if ($lastExitCode -ne ) { throw  }

	$RepoDirName = (Get-Item ).Name
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
