# Check for Microsoft.Update.Installer
# check to see if the installer is busy installing updates
# Date created 04-03-2024
# Date modified 18-06-2024 - Windows 2022 did not show status
#

$GetOS = (Get-WmiObject Win32_OperatingSystem | select -Property * ).Caption
if($GetOS -Notlike '*Windows Server 2022*'){$objectInstaller = New-Object -ComObject "Microsoft.Update.Installer"
$objectInstaller.IsBusy}
if($GetOS -like '*Windows Server 2022*'){$r = ((Get-Counter '\Process(TiWorker)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples | Where-Object {$_.CookedValue -gt 5}).CookedValue
if($r -gt 5){Write-Output "True"} else {Write-Output "False"}}