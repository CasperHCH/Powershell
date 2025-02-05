<#
.SYNOPSIS
	Sets the working directory to the user's screenshots folder
.DESCRIPTION
	This PowerShell script changes the working directory to the user's screenshots folder.
.EXAMPLE
	PS> ./cd-screenshots
	📂C:\Users\Markus\Pictures\Screenshots
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


		if (Test-Path  -pathType container) { $Path =  }
        } else {
                $Path = [Environment]::GetFolderPath('MyPictures')
		if (-not(Test-Path  -pathType container)) { throw  }
		if (Test-Path  -pathType container) { $Path =  }
        }
	return $Path
}

try {
	$Path = GetScreenshotsFolder
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
