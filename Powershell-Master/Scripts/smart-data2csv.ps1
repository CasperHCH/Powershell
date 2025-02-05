<#
.SYNOPSIS
	Converts the S.M.A.R.T. JSON files in a folder to a CSV table for analysis
.DESCRIPTION
	This PowerShell script converts the S.M.A.R.T. JSON files in the current/given directory
	to a CSV table for analysis (use query-smart-data.ps1 to generate those JSON files).
.PARAMETER Directory
	Specifies the path to the directory
.EXAMPLE
	PS> ./smart-data2csv
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Directory = )


	write-host 
}


		4 { write-host -nonewline  }
		7 { write-host -nonewline  }
		9 { write-host -nonewline  }
		12 { write-host -nonewline  }
		190 { write-host -nonewline  }
		191 { write-host -nonewline  }
		192 { write-host -nonewline  }
		193 { write-host -nonewline  }
		195 { write-host -nonewline  }
		240 { write-host -nonewline  }
		241 { write-host -nonewline  }
		242 { write-host -nonewline  }
		default { write-host -nonewline  }
		}
	}
	write-host 
}

try {
	if ($Directory -eq  ) {
		$Directory = 
	}

	$Filenames = get-childitem -path 
	$ModelFamily = $ModelName = $SerialNumber = 

	[int]$Row = 1
	foreach($Filename in $Filenames) {
		$File = get-content $Filename | ConvertFrom-Json

		if ($File.model_family -ne $ModelFamily) {
			if ($ModelFamily -eq ) {
				$ModelFamily = $File.model_family
			} else {
				write-error 
				exit 1
			}
		}
		if ($File.model_name -ne $ModelName) {
			if ($ModelName -eq ) {
				$ModelName = $File.model_name
			} else {
				write-error 
				exit 1
			}
		}
		if ($File.serial_number -ne $SerialNumber) {
			if ($SerialNumber -eq ) {
				$SerialNumber = $File.serial_number
			} else {
				write-error 
				exit 1
			}
		}

		if ($Row -eq 1) {
			WriteCsvHeader $File
		}
		WriteCsvDataRow $File
		$Row++
	}
	exit 0 # success
} catch {
	
	exit 1
}
