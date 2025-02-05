<#
.SYNOPSIS
	Writes code
.DESCRIPTION
	This PowerShell script generates and writes PowerShell code on the console (no AI, just for fun).
.PARAMETER color
	Specifies the text color to use ( by default)
.PARAMETER speed
	Specifies the speed in milliseconds per code line (500 by default)
.EXAMPLE
	PS> ./write-code.ps1
	try {
	...
.LINK
	https://github.com/fleschutz/PowerShell
#>

param([string]$color = , [int]$speed = 500) # milliseconds

[string]$global:Tabs = 


	 1 { return $Tabs +  }
	 2 { return $Tabs +  }
	 3 { return $Tabs +  }
	 4 { return $Tabs +  }
	 5 { return $Tabs +  }
	 6 { $global:Tabs = ; return  }
	 7 { $global:Tabs = ; return  }
	 8 { $global:Tabs = ; return  }
	 9 { return $Tabs + Hello World` }
	10 { $global:Tabs = ; return  }
	11 { return $Tabs +  }
	12 { return $Tabs +  }
	13 { return $Tabs +  }
	14 { return $Tabs +  }
	15 { return $Tabs + Working...` }
	16 { return $Tabs +  }
	17 { return $Tabs +  }
	18 { $global:Tabs = ; return  }
	19 { return $Tabs +  }
	20 { return $Tabs +  }
	21 { $global:Tabs = ; return  }
	22 { $global:Tabs = ; return  }
	23 { return $Tabs + Can't open file` }
	24 { return $Tabs +  }
	25 { return $Tabs + Red or blue pill?` }
	26 { return $Tabs +  }
	27 { $global:Tabs = ; return  }
	28 { $global:Tabs = ; return  }
	29 { $global:Tabs = ; return  }
	30 { $global:Tabs = ; return  }
	}
}

try {
	while ($true) {
		Write-Host -foreground $color 
		Start-Sleep -milliseconds $speed
	}
	exit 0 # success
} catch {
	
	exit 1
}
