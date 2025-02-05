<#
.SYNOPSIS
	Checks the CPU status
.DESCRIPTION
	This PowerShell script queries the CPU status and prints it (name, type, speed, temperature, etc).
.EXAMPLE
	PS> ./check-cpu.ps1
	✅ AMD Ryzen 5 5500U with Radeon Graphics (CPU0, 2100MHz, 31.3°C)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


	} else {
		$Objects = Get-WmiObject -Query  -Namespace 
		foreach ($Obj in $Objects) {
			$HiPrec = $Obj.HighPrecisionTemperature
			$Temp = [math]::round($HiPrec / 100.0, 1)
		}
	}
	return $Temp;
}


	if ($IsLinux) {
		$Name = $PSVersionTable.OS
		if ($Name -like ) {
			if ([System.Environment]::Is64BitOperatingSystem) { return  } else { return  }
		} elseif ($Name -like ) {
			if ([System.Environment]::Is64BitOperatingSystem) { return  } else { return  }
		} else {
			return 
		}
	}
}

try {
	Write-Progress 
	$Status = 
	$Celsius = GetCPUTemperatureInCelsius
	if ($Celsius -eq 99999.9) {
		$Temp = 
	} elseif ($Celsius -gt 50) {
		$Temp = 
		$Status = 
	} elseif ($Celsius -lt 0) {
		$Temp = 
		$Status = 
	} else {
		$Temp = 
	} 

	$Arch = GetProcessorArchitecture
	if ($IsLinux) {
		$CPUName = 
		$Arch = 
		$DeviceID = 
		$Speed = 
		$Socket = 
	} else {
		$Details = Get-WmiObject -Class Win32_Processor
		$CPUName = $Details.Name.trim()
		$Arch = 
		$DeviceID = 
		$Speed = 
		$Socket = 
	}
	$Cores = [System.Environment]::ProcessorCount
	Write-Progress -completed 
	Write-Host 
	exit 0 # success
} catch {
	
	exit 1
}
