<#
.SYNOPSIS
	Lists the latest tag on the current branch in a Git repository
.DESCRIPTION
	This PowerShell script lists the latest tag on the current branch in a Git repository.
.PARAMETER RepoDir
	Specifies the path to the repository
.EXAMPLE
	PS> ./list-latest-tag.ps1 C:\MyRepo
	🔖v0.8 at commit 02171a401d83b01a0cda0af426840b605e617f08
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RepoDir = )

try {
	if (-not(test-path  -pathType container)) { throw  }

	$Null = (git --version)
	if ($lastExitCode -ne ) { throw  }

	$LatestTagCommitID = (git -C  rev-list --tags --max-count=1)
	$LatestTag = (git -C  describe --tags $LatestTagCommitID)
	
	exit 0 # success
} catch {
	
	exit 1
}
