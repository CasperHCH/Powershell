<#
.SYNOPSIS
	Changes the wallpaper
.DESCRIPTION
	This PowerShell script downloads a random photo from Unsplash and sets it as desktop background.
.PARAMETER Category
	Specifies the photo category (beach, city, ...)
.EXAMPLE
	PS> ./change-wallpaper 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Category = )


        if ( -ne )  { return  }
        if ($IsLinux) { return  }
        return 
}

try {
	&  

	$Path = 
	& wget -O $Path 
	if ($lastExitCode -ne ) { throw  }

	&  -ImageFile 
	exit 0 # success
} catch {
	
	exit 1
}
