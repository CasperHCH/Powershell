<#
.SYNOPSIS
Get Server Information
.DESCRIPTION
This script will get the CPU specifications, memory usage statistics, and OS configuration of any Server or Computer listed in Serverlist.txt.
.NOTES  
The script will execute the commands on multiple machines sequentially using non-concurrent sessions. This will process all servers from Serverlist.txt in the listed order.
The info will be exported to a csv format.
Requires: Serverlist.txt must be created in the same folder where the script is.
File Name  : get-server-info.ps1
Author: Nikolay Petkov
http://power-shell.com/
#>
#while(1)
#{
#    $servers = Read-Host 
#    try{ 
#        test-Path $servers 
#        Write-Host 
#        break
#        } 
#    catch {Write-Host }
#}

#Start PSRemoting 
Invoke-Command -ComputerName  -scriptblock { 
#Run the commands concurrently for each server in the list 
$CPUInfo = Get-WmiObject Win32_Processor #Get CPU Information 
$OSInfo = Get-WmiObject Win32_OperatingSystem #Get OS Information 
#Get Memory Information. The data will be shown in a table as MB, rounded to the nearest second decimal. 
$OSTotalVirtualMemory = [math]::round($OSInfo.TotalVirtualMemorySize / 1MB, 2) 
$OSTotalVisibleMemory = [math]::round(($OSInfo.TotalVisibleMemorySize  / 1MB), 2) 
$PhysicalMemory = Get-WmiObject CIM_PhysicalMemory | Measure-Object -Property capacity -Sum | % {[math]::round(($_.sum / 1GB),2)} 
$infoObject = New-Object PSObject 
#The following add data to the infoObjects. 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $CPUInfo.SystemName 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $CPUInfo.Name 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $CPUInfo.Description 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $CPUInfo.Manufacturer 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $CPUInfo.NumberOfCores 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $CPUInfo.L2CacheSize 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $CPUInfo.L3CacheSize 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $CPUInfo.SocketDesignation 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $OSInfo.Caption 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $OSInfo.Version 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $PhysicalMemory 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $OSTotalVirtualMemory 
Add-Member -inputObject $infoObject -memberType NoteProperty -name  -value $OSTotalVisibleMemory 
$infoObject 
} | Select-Object * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName | Export-Csv -path c:\temp\Server_Inventory_$((Get-Date).ToString('MM-dd-yyyy')).csv # -NoTypeInformation results in csv file.
