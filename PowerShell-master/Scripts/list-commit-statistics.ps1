<#
.SYNOPSIS
	Lists the Git commit statistics
.DESCRIPTION
	This PowerShell script lists the commit statistics of a Git repository.
.PARAMETER RepoDir
	Specifies the path to the Git repository.
.EXAMPLE
	PS> ./list-commit-statistics.ps1
  
        Commits Author
        ------- ------
	   2034 Markus Fleschutz <markus.fleschutz@gmail.com>
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RepoDir = )

try {
	Write-Progress 
	$null = (git --version)
	if ($lastExitCode -ne ) { throw  }

	$RepoDirName = (Get-Item ).Name
	Write-Progress 
	if (-not(Test-Path  -pathType container)) { throw  }

	Write-Progress 
	& git -C  fetch --all --quiet
	if ($lastExitCode -ne ) { throw  }

	Write-Progress 
	
	
	
	Write-Progress -completed 
	git -C  shortlog --summary --numbered --email --no-merges
	if ($lastExitCode -ne ) { throw  }
	exit 0 # success
} catch {
	
	exit 1
}
