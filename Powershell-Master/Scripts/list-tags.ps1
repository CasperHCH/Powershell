<#
.SYNOPSIS
	Lists all tags in a repository
.DESCRIPTION
	This PowerShell script fetches all tags of a Git repository and lists it.
.PARAMETER RepoDir
	Specifies the path to the Git repository (current working directory by default)
.PARAMETER SearchPattern
	Specifies the search pattern (anything by default)
.EXAMPLE
	PS> ./list-tags.ps1 C:\MyRepo

	Tag             Description
	---             -----------
	v0.1            Update README.md
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RepoDir = , [string]$SearchPattern=)

try {
	Write-Progress 
	$Null = (git --version)
	if ($lastExitCode -ne ) { throw  }

	Write-Progress 
	if (-not(Test-Path  -pathType container)) { throw  }

	Write-Progress 
	& git -C  fetch --all --tags
	if ($lastExitCode -ne ) { throw  }

	Write-Progress 
	& git -C  fetch --prune --prune-tags
	if ($lastExitCode -ne ) { throw  }

	Write-Progress -completed 
 	
	
	
	& git -C  tag --list  -n
	if ($lastExitCode -ne ) { throw  }
	exit 0 # success
} catch {
	
	exit 1
}
