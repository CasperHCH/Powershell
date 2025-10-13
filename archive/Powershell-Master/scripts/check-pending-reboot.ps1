<#
.SYNOPSIS
	Check for pending reboots
.DESCRIPTION
	This PowerShell script queries pending operating system reboots and prints it.
.EXAMPLE
	./check-pending-reboot.ps1
	✅ No pending reboot.
.LINK
        https://github.com/contoso-org/PowerShell-Scripts
.NOTES
        Author: Enterprise IT Team | License: Enterprise Use Only
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
	[string]$reply = "✅ No pending reboot."
	if ($IsLinux) {
		if (Test-Path "/var/run/reboot-required") {
			$reply = "⚠️ Pending reboot (found: /var/run/reboot-required)"
		}
	} else {
		$reason = ""
		$RegistryPaths = @{
			"AutoUpdateReboot" = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
			"AutoUpdatePost" = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting"
			"ComponentServicing" = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
			"ServerManager" = "HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts"
		}

		if (Test-Path -Path $RegistryPaths["AutoUpdateReboot"]) {
			$reason += ", Windows Update Auto Update\RebootRequired"
		}
		if (Test-Path -Path $RegistryPaths["AutoUpdatePost"]) {
			$reason += ", Windows Update Auto Update\PostRebootReporting"
		}
		if (Test-Path -Path $RegistryPaths["ComponentServicing"]) {
			$reason += ", Component Based Servicing\RebootPending"
		}
		if (Test-Path -Path $RegistryPaths["ServerManager"]) {
			$reason += ", ServerManager\CurrentRebootAttempts"
		}
		$AdditionalRegistryPaths = @{
			"ComponentRebootProgress" = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing"
			"SessionManager" = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
			"RunOnce" = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
			"NetlogonServices" = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon"
		}

		if (Test-RegistryValue -Path $AdditionalRegistryPaths["ComponentRebootProgress"] -Value "RebootInProgress") {
			$reason += ", Component Based Servicing with RebootInProgress"
		}
		if (Test-RegistryValue -Path $AdditionalRegistryPaths["ComponentRebootProgress"] -Value "PackagesPending") {
			$reason += ", Component Based Servicing with PackagesPending"
		}
		if (Test-RegistryValue -Path $AdditionalRegistryPaths["SessionManager"] -Value "PendingFileRenameOperations2") {
			$reason += ", Session Manager with PendingFileRenameOperations2"
		}
		if (Test-RegistryValue -Path $AdditionalRegistryPaths["RunOnce"] -Value "DVDRebootSignal") {
			$reason += ", RunOnce with DVDRebootSignal"
		}
		if (Test-RegistryValue -Path $AdditionalRegistryPaths["NetlogonServices"] -Value "JoinDomain") {
			$reason += ", Netlogon Services with JoinDomain"
		}
		if (Test-RegistryValue -Path $AdditionalRegistryPaths["NetlogonServices"] -Value "AvoidSpnSet") {
			$reason += ", Netlogon Services with AvoidSpnSet"
		}
		if ($reason -ne "") {
			$reply = "⚠️ Pending reboot (registry has $($reason.substring(2)))"
		}
	}
	Write-Host $reply
	exit 0 # success
} catch {
	"⚠️ ERROR: $($Error[0]) (script line $($_.InvocationInfo.ScriptLineNumber))"
        exit 1
}
