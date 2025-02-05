<#
.SYNOPSIS
        Writes a changelog
.DESCRIPTION
        This PowerShell script writes an automated changelog to the console in Markdown format by using the Git commits.
	NOTE: You may also redirect the output into a file for later use.
.EXAMPLE
        PS> ./write-changelog.ps1
	  
	Changelog of PowerShell
	=======================
	...
.LINK
        https://github.com/fleschutz/PowerShell
.NOTES
        Author: Markus Fleschutz | License: CC0
#>

param([string]$RepoDir = )
 
try {
	[system.threading.thread]::currentthread.currentculture = [system.globalization.cultureinfo]

	Write-Progress 
        $null = (git --version)
        if ($lastExitCode -ne ) { throw  }

	Write-Progress 
        if (!(Test-Path  -pathType container)) { throw  }
	$RepoDirName = (Get-Item ).Name

	Write-Progress 
        & git -C  fetch --all --force --quiet
        if ($lastExitCode -ne ) { throw  }

	Write-Progress 
	$commits = (git -C  log --boundary --pretty=oneline --pretty=format:%s | sort -u)

	Write-Progress 
	$features = @()
	$fixes = @()
	$updates = @()
	$various = @()
	foreach($commit in $commits) {
 		if ($commit -like ) {
 			$features += $commit
		} elseif ($commit -like ) {
 			$features += $commit
		} elseif ($commit -like ) {
 			$features += $commit
		} elseif ($commit -like ) {
 			$fixes += $commit
 		} elseif ($commit -like ) {
 			$fixes += $commit
 		} elseif ($commit -like ) {
 			$fixes += $commit
		} elseif ($commit -like ) {
 			$updates += $commit
		} elseif ($commit -like ) {
 			$updates += $commit
		} elseif ($commit -like ) {
 			$updates += $commit
		} elseif ($commit -like ) {
 			$updates += $commit
		} elseif ($commit -like ) {
 			$updates += $commit
		} elseif ($commit -like ) {
 			$updates += $commit
		} elseif ($commit -like ) {
 			$updates += $commit
 		} else {
			$various += $commit
		}
 	}
	Write-Progress 
	$contributors = (git -C  log --format='%aN' | sort -u)
	Write-Progress -completed 

        $Today = (Get-Date).ToShortDateString()
	Write-Output 
	Write-Output 
	Write-Output 
	Write-Output 
	Write-Output 
	Write-Output 
 	foreach($c in $features) {
 		Write-Output 
	}
	Write-Output 
 	Write-Output 
	Write-Output 
 	foreach($c in $fixes) {
 		Write-Output 
 	}
	Write-Output 
	Write-Output 
	Write-Output 
	foreach($c in $updates) {
		Write-Output 
	}
	Write-Output 
	Write-Output 
	Write-Output 
	foreach($c in $various) {
		Write-Output 
	}
	Write-Output 
	Write-Output 
	Write-Output 
	foreach($c in $contributors) {
		Write-Output 
	}
	exit 0 # success
} catch {
	Write-Error $_.Exception.ToString()
	exit 1
}
