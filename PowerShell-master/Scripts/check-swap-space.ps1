<#
.SYNOPSIS
	Checks the swap space status
.DESCRIPTION
	This PowerShell script queries the status of the swap space and prints it.
.PARAMETER minLevel
	Specifies the minimum level in GB (10 GB by default)
.EXAMPLE
	PS> ./check-swap-space.ps1
	✅ Swap space uses 42% of 1GB, 748MB free
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([int]$minLevel = 10)


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
	[int64]$Total = [int64]$Used = [int64]$Free = 0
	if ($IsLinux) {
		$Result = $(free --mega | grep Swap:)
		[int64]$Total = $Result.subString(5,14)
		[int64]$Used = $Result.substring(20,13)
		[int64]$Free = $Result.substring(32,11)
	} else {
		$Items = Get-WmiObject -class  -namespace  -computername localhost 
		foreach ($Item in $Items) { 
			$Total += $Item.AllocatedBaseSize
			$Used += $Item.CurrentUsage
			$Free += ($Total - $Used)
		} 
	}
	if ($Total -eq 0) {
        	Write-Output 
	} elseif ($Free -eq 0) {
		Write-Output 
	} elseif ($Free -lt $minLevel) {
		Write-Output 
	} elseif ($Used -eq 0) {
		Write-Output 
	} else {
		[int]$Percent = ($Used * 100) / $Total
		Write-Output 
	}
	exit 0 # success
} catch {
	
	exit 1
}
