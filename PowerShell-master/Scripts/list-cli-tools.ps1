<#
.SYNOPSIS
	Lists command-line tools
.DESCRIPTION
	This PowerShell script lists installed command-line interface (CLI) tools (sorted alphabetically by name).
.EXAMPLE
	PS> ./list-cli-tools.ps1

	Tool         Version         Path                                          FileSize
	----         -------         ----                                          --------
	at           10.0.19041.1    C:\WINDOWS\system32\at.exe                    31232
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

 elseif ( -match '\d+\.\d+') {
					$Version = 
				} else {
					$Version = 
				}
			} else {
				$Version = 
			}
		} else {
			$Version = $Info.Version
		}
		if (Test-Path  -pathType leaf) {
			$Size = (Get-Item ).Length
		} else {
			$Size = 0
		}
		New-Object PSObject -Property @{ Tool=$Name; Version=$Version; Path=$Path; FileSize=$Size }
	} catch {
		return
	}
}


 
try {
	ListTools | Format-Table -property @{e='Tool';width=12},@{e='Version';width=15},@{e='Path';width=70},@{e='FileSize';width=10}
	exit 0 # success
} catch {
	
	exit 1
}
