<#
.SYNOPSIS
	Lists a folder
.DESCRIPTION
	This PowerShell script lists the content of a directory (alphabetically formatted in columns).
.PARAMETER SearchPattern
	Specifies the search pattern ( by default which means anything)
.EXAMPLE
	PS> ./list-folder.ps1 C:\*
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$searchPattern = )


		{return }
	  {return }
		{return }
		{return }
		{return }
		{return }
		{return }
	  {return }
	default {return }
	}
}

 # hidden file/dir
		if ($item.Mode -like ) { $icon =  } else { $icon = GetFileIcon $item.Extension }
		New-Object PSObject -property @{ Name =  }
	}
}

try {
	ListFolder $searchPattern | Format-Wide -autoSize
	exit 0 # success
} catch {
	
	exit 1
}
