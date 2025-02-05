<#
.SYNOPSIS
	Configures Git 
.DESCRIPTION
	This PowerShell script configures the Git user settings.
.PARAMETER fullName
	Specifies the user's full name
.PARAMETER emailAddress
	Specifies the user's email address
.PARAMETER favoriteEditor
	Specifies the user's favorite text editor
.EXAMPLE
	PS> ./configure-git.ps1  joe@doe.com vim
	⏳ (1/6) Searching for Git executable...  git version 2.42.0.windows.1
	⏳ (2/6) Query user settings...
	⏳ (3/6) Saving basic settings (autocrlf,symlinks,longpaths,etc.)...
	⏳ (4/6) Saving user settings (name,email,editor)...
	⏳ (5/6) Saving user shortcuts ('git br', 'git ls', 'git st', etc.)...
	⏳ (6/6) Listing your current settings...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$fullName = , [string]$emailAddress = , [string]$favoriteEditor = )

try {
	Write-Host  -noNewline
	& git --version
	if ($lastExitCode -ne ) { throw  }

	
	if ($fullName -eq ) { $fullName = Read-Host  }
	if ($emailAddress -eq ) { $emailAddress = Read-Host }
	if ($favoriteEditor -eq ) { $favoriteEditor = Read-Host  }
	$stopWatch = [system.diagnostics.stopwatch]::startNew()

	
	& git config --global core.autocrlf false          # don't change newlines
	& git config --global core.symlinks true           # enable support for symbolic link files
	& git config --global core.longpaths true          # enable support for long file paths
	& git config --global init.defaultBranch main      # set the default branch name to 'main'
	& git config --global merge.renamelimit 99999      # raise the rename limit
	& git config --global pull.rebase false
	& git config --global fetch.parallel 0             # enable parallel fetching to improve the speed
	if ($lastExitCode -ne ) { throw  }

	
	& git config --global user.name $fullName
	& git config --global user.email $emailAddress
	& git config --global core.editor $favoriteEditor
	if ($lastExitCode -ne ) { throw  }

	
	& git config --global alias.br 
	& git config --global alias.chp 
	& git config --global alias.ci 
	& git config --global alias.co 
	& git config --global alias.ls 
	& git config --global alias.mrg 
	& git config --global alias.pl 
	& git config --global alias.ps 
	& git config --global alias.smu 
	& git config --global alias.st 
	if ($lastExitCode -ne ) { throw  }

	
	& git config --list
	if ($lastExitCode -ne ) { throw  }

	[int]$elapsed = $stopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
