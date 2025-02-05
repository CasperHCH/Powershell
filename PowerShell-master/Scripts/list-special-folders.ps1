<#
.SYNOPSIS
	Lists special folders
.DESCRIPTION
	This PowerShell script lists all special folders (sorted alphabetically).
.EXAMPLE
	PS> ./list-special-folders.ps1

	Folder Name     Folder Path
	-----------     -----------
	AdminTools      📂C:\Users\Markus\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Administrative Tools
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


        if ( -ne )  { return  }
        if ($IsLinux) { return  }
        return 
}


	}
}

 else {
		$FolderNames = [System.Enum]::GetNames('System.Environment+SpecialFolder')
		$FolderNames | Sort-Object | ForEach-Object {
			if ($Path = [System.Environment]::GetFolderPath($_)) {
				AddLine  
			}
		}
		AddLine      
		AddLine               
		AddLine         
		$Path = Resolve-Path 
		AddLine             
	}
}

try {
	ListSpecialFolders | Format-Table -property @{e='Folder Name';width=18},'Folder Path'
	exit 0 # success
} catch {
	
	exit 1
}
