<#
.SYNOPSIS
	Checks the drive space
.DESCRIPTION
	This PowerShell script queries the free space of all drives and prints it.
.PARAMETER minLevel
	Specifies the minimum warning level (10 GB by default)
.EXAMPLE
	PS> ./check-drives.ps1
	✅ Drive C: uses 49% of 1TB, 512GB free
	✅ Drive D: uses 84% of 4TB, 641GB free
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([int64]$minLevel = 10) # 10 GB minimum


        $bytes /= 1000
        if ($bytes -lt 1000) { return  }
        $bytes /= 1000
        if ($bytes -lt 1000) { return  }
        $bytes /= 1000
        if ($bytes -lt 1000) { return  }
        $bytes /= 1000
        if ($bytes -lt 1000) { return  }
        $bytes /= 1000
        return 
}

try {
	Write-Progress 
	$drives = Get-PSDrive -PSProvider FileSystem
	$minLevel *= 1000 * 1000 * 1000
	Write-Progress -completed 
	foreach($drive in $drives) {
		$details = (Get-PSDrive $drive.Name)
		if ($IsLinux) { $name = $drive.Name } else { $name = $drive.Name +  }
		[int64]$free = $details.Free
 		[int64]$used = $details.Used
		[int64]$total = ($used + $free)

		if ($total -eq 0) {
			Write-Host 
		} elseif ($free -eq 0) {
			Write-Host 
		} elseif ($free -lt $minLevel) {
			Write-Host 
		} else {
			[int]$percent = ($used * 100) / $total
			Write-Host 
		}
	}
	exit 0 # success
} catch {
	
	exit 1
}
