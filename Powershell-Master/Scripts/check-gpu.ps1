<#
.SYNOPSIS
        Checks the GPU status
.DESCRIPTION
        This PowerShell script queries the GPU status and prints it.
.EXAMPLE
        PS> ./check-gpu.ps1
	✅ NVIDIA Quadro P400 GPU (2GB RAM, 3840x2160 pixels, 32 bit, 59 Hz, driver 31.0.15.1740, status OK)
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
        return 
}

try {
	if ($IsLinux) {
		# TODO
	} else {
		$Details = Get-WmiObject Win32_VideoController
		$Model = $Details.Caption
		$RAMSize = $Details.AdapterRAM
		$ResWidth = $Details.CurrentHorizontalResolution
		$ResHeight = $Details.CurrentVerticalResolution
		$BitsPerPixel = $Details.CurrentBitsPerPixel
		$RefreshRate = $Details.CurrentRefreshRate
		$DriverVersion = $Details.DriverVersion
		$Status = $Details.Status
		Write-Host 
	}
	exit 0 # success
} catch {
        
        exit 1
}
