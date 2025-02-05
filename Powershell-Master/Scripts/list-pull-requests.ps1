<#
.SYNOPSIS
        Lists all pull requests
.DESCRIPTION
        This PowerShell script lists all pull requests for a Git repository.
.PARAMETER RepoDir
        Specifies the file path to the local Git repository (default is working directory).
.EXAMPLE
        PS> ./list-pull-requests.ps1 C:\MyRepo
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

        Write-Progress 
        if (!(Test-Path  -pathType container)) { throw  }
        $RepoDirName = (Get-Item ).Name

        Write-Progress 
        & git -C  fetch --all --force --quiet
        if ($lastExitCode -ne ) { throw  }
	Write-Progress -completed 

	
	
	
	& git -C  ls-remote origin 'pull/*/head'
	if ($lastExitCode -ne ) { throw  }
	Write-Progress -completed 
	exit 0 # success
} catch {
        
        exit 1
}
