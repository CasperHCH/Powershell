<#
.SYNOPSIS
	Removes a Git tag (locally, remote, or both)
.DESCRIPTION
	This PowerShell script removes a Git tag, either locally, remote, or both.
.PARAMETER TagName
	Specifies the Git tag name
.PARAMETER Mode
	Specifies either locally, remote, or both
.PARAMETER RepoDir
	Specifies the path to the Git repository
.EXAMPLE
	PS> ./remove-tag v1.7 locally
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$TagName = , [string]$Mode = , [string]$RepoDir = )

try {
	if ($TagName -eq ) { $TagName = read-host  }
	if ($Mode -eq ) { $Mode = read-host  }

	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if (-not(test-path  -pathType container)) { throw  }

	$Null = (git --version)
	if ($lastExitCode -ne ) { throw  }

	if (($Mode -eq ) -or ($Mode -eq )) {
		
		& git -C  tag --delete $TagName
		if ($lastExitCode -ne ) { throw  }
	}

	if (($Mode -eq ) -or ($Mode -eq )) {
		
		& git -C  push origin :refs/tags/$TagName
		if ($lastExitCode -ne ) { throw  }
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
