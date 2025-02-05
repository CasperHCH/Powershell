<#
.SYNOPSIS
	Lists Git branches
.DESCRIPTION
	This PowerShell script lists all branches in a Git repository.
.PARAMETER RepoDir
	Specifies the path to the Git repository (current working directory by default)
.PARAMETER SearchPattern
	Specifies the search patter (anything by default)
.EXAMPLE
	PS> ./list-branches.ps1

	List of Git Branches
	--------------------
	main
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RepoDir = , [string]$SearchPattern = )

try {
	if (-not(test-path  -pathType container)) { throw  }

	$Null = (git --version)
	if ($lastExitCode -ne ) { throw  }

	& git -C  fetch 
	if ($lastExitCode -ne ) { throw  }

	$Branches = $(git -C  branch --list --remotes --no-color --no-column)
	if ($lastExitCode -ne ) { throw  }

	
	
	
	foreach($Branch in $Branches) {
		if ( -match ) { continue }
		$BranchName = $Branch.substring(9)
		if ( -notlike ) { continue }
		
	}
	
	exit 0 # success
} catch {
	
	exit 1
}
