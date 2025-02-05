<#
.SYNOPSIS
	Cleans all Git repositories in a folder from untracked files 
.DESCRIPTION
	This PowerShell script cleans all Git repositories in a folder from untracked files (including submodules).
.PARAMETER ParentDir
	Specifies the path to the parent folder
.EXAMPLE
	PS> ./clean-repos C:\MyRepos
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$ParentDir = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -noNewline
        & git --version
        if ($lastExitCode -ne ) { throw  }

        $ParentDirName = (Get-Item ).Name
        Write-Host  -noNewline
        if (-not(Test-Path  -pathType container)) { throw  }
        $Folders = (Get-ChildItem  -attributes Directory)
        $NumFolders = $Folders.Count
        Write-Host 

	[int]$Step = 2
	foreach ($Folder in $Folders) {
		$FolderName = (Get-Item ).Name
		$Step++
		

		& git -C  clean -xfd -f # force + recurse into dirs + don't use the standard ignore rules
		if ($lastExitCode -ne ) { throw  }

		& git -C  submodule foreach --recursive git clean -xfd -f 
		if ($lastExitCode -ne ) { throw  }
	}
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
