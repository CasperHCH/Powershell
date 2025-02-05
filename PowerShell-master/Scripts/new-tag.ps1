<#
.SYNOPSIS
	Creates a new tag in a Git repository
.DESCRIPTION
	This PowerShell script creates a new tag in a Git repository.
.PARAMETER TagName
	Specifies the new tag name
.PARAMETER RepoDir
	Specifies the path to the Git repository
.EXAMPLE
	PS> ./new-tag.ps1 v1.7
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$TagName = , [string]$RepoDir = )

try {
	if ($TagName -eq ) { $TagName = read-host  }

	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if (-not(test-path  -pathType container)) { throw  }
	set-location 

	$Null = (git --version)
	if ($lastExitCode -ne ) { throw  }

	$Result = (git status)
	if ($lastExitCode -ne ) { throw  }
	if ( -notmatch ) { throw  }

	& 
	if ($lastExitCode -ne ) { throw  }

	& git tag 
	if ($lastExitCode -ne ) { throw  }

	& git push origin 
	if ($lastExitCode -ne ) { throw  }

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
