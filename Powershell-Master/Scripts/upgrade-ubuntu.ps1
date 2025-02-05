<#
.SYNOPSIS
	Upgrades Ubuntu Linux 
.DESCRIPTION
	This PowerShell script upgrades Ubuntu Linux to the latest (LTS) release.
.EXAMPLE
	PS> .\upgrade-ubuntu.ps1 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	
	
	
	$Confirm = Read-Host 

	
	
	$Confirm = Read-Host 
	if ($Confirm -eq ) {
		sudo apt install update-manager-core
		sudo apt update
		sudo apt list --upgradable
		sudo apt upgrade
		sudo reboot 
	}

	
	
	$Confirm = Read-Host 
	if ($Confirm -eq ) {
		sudo apt --purge autoremove
	}

	
	
	$Confirm = Read-Host 
	if ($Confirm -eq ) {
		sudo do-release-upgrade
		sudo reboot
	} elseif ($Confirm -eq ) {
		sudo do-release-upgrade -d
		sudo reboot
	}

	
	exit 0 # success
} catch {
	
	exit 1
}
