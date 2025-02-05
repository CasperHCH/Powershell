<#
.SYNOPSIS
	Creates a new shortcut file
.DESCRIPTION
	This PowerShell script creates a new shortcut file.
.PARAMETER shortcut
	Specifies the shortcut filename
.PARAMETER target
	Specifies the path to the target
.PARAMETER description
	Specifies a description
.EXAMPLE
	PS> ./new-shortcut C:\Temp\HDD C:\
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$shortcut = , [string]$target = , [string]$description)

try {
	if ($shortcut -eq  ) { $shortcut = read-host  }
	if ($target -eq  ) { $target = read-host  }
	if ($description -eq  ) { $description = read-host  }

	$sh = new-object -ComObject WScript.Shell
	$sc = $sh.CreateShortcut()
	$sc.TargetPath = 
	$sc.WindowStyle = 
	$sc.IconLocation = 
	$sc.Description = 
	$sc.save()

	
	exit 0 # success
} catch {
	
	exit 1
}
