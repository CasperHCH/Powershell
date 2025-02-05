<#
.SYNOPSIS
	Lists Git commits
.DESCRIPTION
	This PowerShell script lists all commits in a Git repository. Supported output formats are: pretty, list, compact, normal or JSON.
.PARAMETER RepoDir
	Specifies the path to the Git repository.
.PARAMETER Format
	Specifies the output format: pretty|list|compact|normal|JSON (pretty by default)
.EXAMPLE
	PS> ./list-commits

	ID      Date                            Committer               Description
	--      ----                            ---------               -----------
	ccd0d3e Wed Sep 29 08:28:20 2021 +0200  Markus Fleschutz        Fix typo
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RepoDir = , [string]$Format = )

try {
	if (-not(Test-Path  -pathType container)) { throw  }

	$Null = (git --version)
	if ($lastExitCode -ne ) { throw  }

	Write-Progress 
	& git -C  fetch --all --quiet
	if ($lastExitCode -ne ) { throw  }
	Write-Progress -Completed 

	if ($Format -eq ) {
		
		& git -C  log --graph --format=format:'%C(bold yellow)%s%C(reset)%d by %an 🕘%cs 🔗%h' --all
	} elseif ($Format -eq ) {
		
		
		
		& git log --pretty=format:
	} elseif ($Format -eq ) {
		
		
		
		& git -C  log --graph --pretty=format:'%Cred%h%Creset%C(yellow)%d%Creset %s %C(bold blue)by %an %cr%Creset' --abbrev-commit
		if ($lastExitCode -ne ) { throw  }
	} elseif ($Format -eq ) {
		& git -C  log --pretty=format:'{%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : ,%n  : {%n    : ,%n    : ,%n    : %n  },%n  : {%n    : ,%n    : ,%n    : %n  }%n},'
	} else {
		
		
		
		& git -C  log
		if ($lastExitCode -ne ) { throw  }
	}
	exit 0 # success
} catch {
	
	exit 1
}
