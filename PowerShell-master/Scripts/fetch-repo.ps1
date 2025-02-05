<#
.SYNOPSIS
	Fetches Git repository updates
.DESCRIPTION
	This PowerShell script fetches the latest updates into a local Git repository (including submodules).
.PARAMETER RepoDir
	Specifies the file path to the local Git repository (default is working directory).
.EXAMPLE
	PS> ./fetch-repo.ps1 C:\MyRepo
	⏳ (1/3) Searching for Git executable...  git version 2.41.0.windows.3
	⏳ (2/3) Checking local repository...
	⏳ (3/3) Fetching updates...
	✔️ Fetched updates into repo 📂MyRepo (took 2 sec)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RepoDir = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -noNewline
	& git --version
	if ($lastExitCode -ne ) { throw  }

	Write-Host 
	if (!(Test-Path  -pathType container)) { throw  }
	$RepoDirName = (Get-Item ).Name

	Write-Host 
	& git -C  fetch --all --recurse-submodules --tags --prune --prune-tags --force --quiet
	if ($lastExitCode -ne ) { throw  }
	
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
