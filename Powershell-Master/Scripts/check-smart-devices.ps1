<#
.SYNOPSIS
	Checks the SMART device status
.DESCRIPTION
	This PowerShell script queries the status of the SSD/HDD devices (supporting S.M.A.R.T.) and prints it.
.EXAMPLE
	PS> ./check-smart-devices.ps1
	✅ 1TB Samsung SSD 970 EVO via NVMe (2388 hours, 289x on, v2B2QEXE7, 37°C, selftest passed)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


	$Bytes /= 1000
	if ($Bytes -lt 1000) { return  }
	$Bytes /= 1000
	if ($Bytes -lt 1000) { return  }
	$Bytes /= 1000
	if ($Bytes -lt 1000) { return  }
	$Bytes /= 1000
	if ($Bytes -lt 1000) { return  }
	$Bytes /= 1000
	if ($Bytes -lt 1000) { return  }
	$Bytes /= 1000
	if ($Bytes -lt 1000) { return  }
}

try {
	Write-Progress 
	$Result = (smartctl --version)
	if ($lastExitCode -ne ) { throw  }

	Write-Progress 
	if ($IsLinux) {
		$Devices = $(sudo smartctl --scan-open)
	} else {
		$Devices = $(smartctl --scan-open)
	}

	foreach($Device in $Devices) {
		Write-Progress 
		$Array = $Device.split()
		$Device = $Array[0]
		if ( -eq ) {
			continue
		} elseif ($IsLinux) {
			$Details = (sudo smartctl --all --json $Device) | ConvertFrom-Json
			$null = (sudo smartctl --test=short $Device)
		} else {
			$Details = (smartctl --all --json $Device) | ConvertFrom-Json
			$null = (smartctl --test=short $Device)
		}
		$ModelName = $Details.model_name
		$Protocol = $Details.device.protocol
		[int64]$GBytes = $Details.user_capacity.bytes
		if ($GBytes -gt 0) {
			$Capacity = 
		} else {
			$Capacity = 
		}
		$Temp = $Details.temperature.current
		$Firmware = $Details.firmware_version
		$PowerOn = $Details.power_cycle_count
		$Hours = $Details.power_on_time.hours
		if ($Details.smart_status.passed) { $Status =  } else { $Status =  }
		Write-Progress -completed 
		Write-Host 
	}
	exit 0 # success
} catch {
	
	exit 1
}
