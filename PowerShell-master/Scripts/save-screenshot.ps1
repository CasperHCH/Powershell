<#
.SYNOPSIS
	Saves a single screenshot
.DESCRIPTION
	This PowerShell script takes a single screenshot and saves it into a target folder (default is the user's screenshots folder).
.PARAMETER TargetFolder
	Specifies the target folder (the user's screenshots folder by default)
.EXAMPLE
	PS> ./save-screenshot
 	✔️ screenshot saved to C:\Users\Markus\Pictures\Screenshots\2021-10-10T14-33-22.png
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$TargetFolder = )


                if (Test-Path  -pathType container) { $Path =  }
        } else {
                $Path = [Environment]::GetFolderPath('MyPictures')
                if (-not(Test-Path  -pathType container)) { throw  }
                if (Test-Path  -pathType container) { $Path =  }
        }
        return $Path
}



try {
	if ( -eq ) { $TargetFolder = GetScreenshotsFolder }
	$Time = (Get-Date)
	$Filename = 
	$FilePath = (Join-Path $TargetFolder $Filename)
	TakeScreenshot $FilePath

	
	exit 0 # success
} catch {
	
	exit 1
}
