<#
.SYNOPSIS
	Checks the RAM
.DESCRIPTION
	This PowerShell script queries the status of the installed RAM memory modules and prints it.
.EXAMPLE
	PS> ./check-ram.ps1
	✅ 16GB DDR4 RAM @ 3200MHz by Micron (in CPU0/CPU0-DIMM3 @ 1.2V)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


	5 { return  }
	6 { return  }
	7 { return  }
	8 { return  }
	10 { return  }
	11 { return  }
	12 { return  }
	13 { return  }
	14 { return  }
	15 { return  }
	16 { return  }
	17 { return  }
	18 { return  }
	19 { return  }
	20 { return  }
	21 { return  }
	22 { return  }
	24 { return  }
	26 { return  }
	27 { return  }
	28 { return  }
	29 { return  }
	default { return  }
	}
}


        $Bytes /= 1024
        if ($Bytes -lt 1024) { return  }
        $Bytes /= 1024
        if ($Bytes -lt 1024) { return  }
        $Bytes /= 1024
        if ($Bytes -lt 1024) { return  }
        $Bytes /= 1024
        if ($Bytes -lt 1024) { return  }
        $Bytes /= 1024
        if ($Bytes -lt 1024) { return  }
        $Bytes /= 1024
        if ($Bytes -lt 1024) { return  }
}

try {
	if ($IsLinux) {
		# TODO
	} else {
		$Banks = Get-WmiObject -Class Win32_PhysicalMemory
		foreach ($Bank in $Banks) {
			$Capacity = Bytes2String($Bank.Capacity)
			$Type = GetRAMType $Bank.SMBIOSMemoryType
			$Speed = $Bank.Speed
			[float]$Voltage = $Bank.ConfiguredVoltage / 1000.0
			$Manufacturer = $Bank.Manufacturer
			$Location = 
			Write-Host 
		}
	}
	exit 0 # success
} catch {
	
	exit 1
}
