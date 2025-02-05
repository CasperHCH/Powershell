<#
.SYNOPSIS
	Shows a notification
.DESCRIPTION
	This PowerShell script shows a toast-message notification for the Windows 10 Notification Center.
.EXAMPLE
	PS> ./show-notification 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Text = , [string]$Title = , [int]$Duration = 5000)

try {
	Add-Type -AssemblyName System.Windows.Forms 
	$global:balloon = New-Object System.Windows.Forms.NotifyIcon
	$path = (Get-Process -id $pid).Path
	$balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path) 
	$balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
	$balloon.BalloonTipText = $Text
	$balloon.BalloonTipTitle = $Title 
	$balloon.Visible = $true 
	$balloon.ShowBalloonTip($Duration)
	exit 0 # success
} catch {
	
	exit 1
}
