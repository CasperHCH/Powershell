<#
.SYNOPSIS
	Synchronizes a repo 
.DESCRIPTION
	This PowerShell script synchronizes a local Git repository by pull and push (including submodules).
.PARAMETER path
	Specifies the path to the Git repository
.EXAMPLE
	PS> ./sync-repo.ps1 C:\MyRepo
	⏳ (1/4) Searching for Git executable...  git version 2.42.0.windows.1
	⏳ (2/4) Checking local repository...     📂C:\MyRepo
	⏳ (3/4) Pulling remote updates...        Already up to date.
	⏳ (4/4) Pushing local updates...         Everything up-to-date
	✔️ Synced repo 📂MyRepo in 5 sec
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$path = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -noNewline
 	& git --version
 	if ($lastExitCode -ne ) { throw  }

	Write-Host 
	if (!(Test-Path  -pathType container)) { throw  }
	$pathName = (Get-Item ).Name

	Write-Host  -noNewline
	& git -C  pull --all --recurse-submodules
	if ($lastExitCode -ne ) { throw  }

	Write-Host  -noNewline
	& git -C  push
	if ($lastExitCode -ne ) { throw  }

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
