<#
.SYNOPSIS
	Sets the working directory to the temporary folder
.DESCRIPTION
	This PowerShell script changes the working directory to the temporary folder.
.EXAMPLE
	PS> ./cd-temp
	📂C:\Users\Markus\AppData\Local\Temp
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


        if ( -ne )  { return  }
        if ($IsLinux) { return  }
        return 
}

try {
	$Path = GetTempDir
	if (-not(Test-Path  -pathType container)) { throw  }
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
