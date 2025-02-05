<#
.SYNOPSIS
	Lists the latests tags in all Git repositories in a folder
.DESCRIPTION
	This PowerShell script lists the latest tags in all Git repositories in the specified folder.
.PARAMETER ParentDir
	Specifies the path to the parent folder
.EXAMPLE
	PS> ./list-latest-tags C:\MyRepos
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$ParentDir = )

try {
	if (-not(test-path  -pathType container)) { throw  }

	$Null = (git --version)
	if ($lastExitCode -ne ) { throw  }

	$Folders = (get-childItem  -attributes Directory)
	$FolderCount = $Folders.Count
	$ParentDirName = (get-item ).Name
	

	foreach ($Folder in $Folders) {
		$FolderName = (get-item ).Name

#		& git -C  fetch --tags
#		if ($lastExitCode -ne ) { throw  }

		$LatestTagCommitID = (git -C  rev-list --tags --max-count=1)
		$LatestTag = (git -C  describe --tags $LatestTagCommitID)
		
	}
	exit 0 # success
} catch {
	
	exit 1
}
