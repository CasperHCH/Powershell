<#
.SYNOPSIS
	Cherry-picks a Git commit into one or more branches
.DESCRIPTION
	Cherry-picks a Git commit into one or more branches (branch names need to be separated by spaces)
	NOTE: in case of merge conflicts the script stops immediately! 
.PARAMETER CommitID
	Specifies the commit ID
.PARAMETER CommitMessage
	Specifies the commit message to use
.PARAMETER Branches
	Specifies the list of branches, separated by spaces
.PARAMETER RepoDir
	Specifies the path to the Git repository
.EXAMPLE
	PS> ./pick-commit 93849f889  
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$CommitID = , [string]$CommitMessage = , [string]$Branches = , [string]$RepoDir = )

try {
	if (-not(Test-Path  -pathType container)) { throw  }
	Set-Location 

	if ($CommitID -eq ) { $CommitID = read-host  }
	if ($CommitMessage -eq ) { $CommitMessage = read-host  }
	if ($Branches -eq ) { $Branches = read-host  }
	
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	$BranchArray = $Branches.Split()
	$NumBranches = $BranchArray.Count
	foreach($Branch in $BranchArray) {

		
		& git checkout --recurse-submodules --force $Branch
		if ($lastExitCode -ne ) { throw  }

		
		& git submodule update --init --recursive
		if ($lastExitCode -ne ) { throw  }

		
		& git clean -fdx -f
		if ($lastExitCode -ne ) { throw  }
			
		& git submodule foreach --recursive git clean -fdx -f
		if ($lastExitCode -ne ) { throw  }

		
		& git pull --recurse-submodules 
		if ($lastExitCode -ne ) { throw  }

		
		$Result = (git status)
		if ($lastExitCode -ne ) { throw  }
		if ( -notmatch ) { throw  }

		
		& git cherry-pick --no-commit 
		if ($lastExitCode -ne ) { throw  }

		
		& git commit -m 
		if ($lastExitCode -ne ) { throw  }

		
		& git push
		if ($lastExitCode -ne ) { throw  }
	}
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
