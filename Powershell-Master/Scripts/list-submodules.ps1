<#
.SYNOPSIS
	Lists the submodules in a Git repository
.DESCRIPTION
	This PowerShell script lists the submodules in the given Git repository.
.PARAMETER RepoDir
	Specifies the path to the repository (current working directory by default)
.EXAMPLE
	PS> ./list-submodules.ps1 C:\MyRepo
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RepoDir = )

try {
	Write-Host  -noNewline
	& git --version
	if ($lastExitCode -ne ) { throw  }

	$RepoDirName = (Get-Item ).Name
	Write-Host 
	if (-not(Test-Path  -pathType container)) { throw  }

	Write-Host 
	& git -C  fetch
	if ($lastExitCode -ne ) { throw  }

	Write-Host 
	& git -C  submodule
	if ($lastExitCode -ne ) { throw  }

	exit 0 # success
} catch {
	
	exit 1
}
