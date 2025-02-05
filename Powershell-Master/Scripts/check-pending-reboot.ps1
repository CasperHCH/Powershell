<#
.SYNOPSIS
	Check for pending reboots
.DESCRIPTION
	This PowerShell script queries pending operating system reboots and prints it.
.EXAMPLE
	./check-pending-reboot.ps1
	✅ No pending reboot
.LINK
        https://github.com/fleschutz/PowerShell
.NOTES
        Author: Markus Fleschutz | License: CC0
#>

function Test-RegistryValue { param([parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Path, [parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()]$Value)
	try {
		Get-ItemProperty -Path $Path -Name $Value -EA Stop
		return $true
	} catch {
		return $false
	}
}

try {
	$Reason = 
	if ($IsLinux) {
		if (Test-Path ) {
			$Reason = 
			Write-Host 
		}
	} else {
		if (Test-Path -Path ) {
			$Reason += 
		}
		if (Test-Path -Path ) {
			$Reason += 
		}
		if (Test-Path -Path ) {
			$Reason += 
		}
		if (Test-Path -Path ) {
			$Reason += 
		}
		if (Test-RegistryValue -Path  -Value ) {
			$Reason += 
		}
		if (Test-RegistryValue -Path  -Value ) {
			$Reason += 
		}
		if (Test-RegistryValue -Path  -Value ) {
			$Reason += 
		}
		if (Test-RegistryValue -Path  -Value ) {
			$Reason += 
		}
		if (Test-RegistryValue -Path  -Value ) {
			$Reason += 
		}
		if (Test-RegistryValue -Path  -Value ) {
			$Reason += 
		}
		if ($Reason -ne ) {
			Write-Host 
		}
	}
	if ($Reason -eq ) {
		Write-Host 
	}
	exit 0 # success
} catch {
        
        exit 1
}
