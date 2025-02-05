<#
.SYNOPSIS
	Lists Git repos
.DESCRIPTION
	This PowerShell script lists details of all Git repositories in a folder.
.PARAMETER ParentDir
	Specifies the path to the parent directory.
.EXAMPLE
	PS> ./list-repos C:\MyRepos
	
	Repository   Latest Tag   Branch    Status    Remote
	----------   ----------   ------    ------    ------
	📂cmake      v3.23.0      main      ✔️clean    git@github.com:Kitware/CMake ↓0
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$ParentDir = )

 else {
			$LatestTag = 
		}
		$Branch = (git -C  branch --show-current)
		$RemoteURL = (git -C  remote get-url origin)
		$NumCommits = (git -C  rev-list HEAD...origin/$Branch --count)
		$Status = (git -C  status --short)
		if ( -eq ) { $Status =  }
		elseif ( -like ) { $Status =  }
		New-Object PSObject -property @{'Repository'=;'Latest Tag'=;'Branch'=;'Status'=;'Remote'=;}
	}
}

try {
	if (-not(Test-Path  -pathType container)) { throw  }

	$Null = (git --version)
	if ($lastExitCode -ne ) { throw  }

	ListRepos | Format-Table -property @{e='Repository';width=20},@{e='Latest Tag';width=18},@{e='Branch';width=20},@{e='Status';width=10},Remote
	exit 0 # success
} catch {
	
	exit 1
}
