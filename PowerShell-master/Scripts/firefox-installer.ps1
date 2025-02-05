<#
.SYNOPSIS
	firefox installer
.DESCRIPTION
	Download and install latest firefox 
.EXAMPLE
	PS> ./firefox-installer.ps1
	                            
.LINK
	https://github.com/pakoti/Awesome_Sysadmin
.NOTES
	Author: Dark Master | License: CC0-1,0
#>





try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	$Path = $env:TEMP;
	$Installer = 
	Invoke-WebRequest  -OutFile $Path\$Installer
	Start-Process -FilePath $Path\$Installer -Args  -Verb RunAs -Wait
	Remove-Item $Path\$Installer

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # successfully installed firefox
} catch {
	
	exit 1
}
