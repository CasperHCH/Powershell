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
#    $servers = Read-Host "Please provide the filepath for the serverlist.txt ( CSV ) file."
#    try{ 
#        test-Path $servers 
#        Write-Host "filepath provided is valid"
#        break
#        } 
#    catch {Write-Host "NOT a valid path, try again"}
#}

#Start PSRemoting 
Invoke-Command -ComputerName "confluence-prod.miracle.local" -scriptblock { 
#Run the commands concurrently for each server in the list 
$CPUInfo = Get-WmiObject Win32_Processor #Get CPU Information 
$OSInfo = Get-WmiObject Win32_OperatingSystem #Get OS Information 
#Get Memory Information. The data will be shown in a table as MB, rounded to the nearest second decimal. 
$OSTotalVirtualMemory = [math]::round($OSInfo.TotalVirtualMemorySize / 1MB, 2) 
$OSTotalVisibleMemory = [math]::round(($OSInfo.TotalVisibleMemorySize  / 1MB), 2) 
$PhysicalMemory = Get-WmiObject CIM_PhysicalMemory | Measure-Object -Property capacity -Sum | % {[math]::round(($_.sum / 1GB),2)} 
$infoObject = New-Object PSObject 
#The following add data to the infoObjects. 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "ServerName" -value $CPUInfo.SystemName 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "CPU_Name" -value $CPUInfo.Name 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "CPU_Description" -value $CPUInfo.Description 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "CPU_Manufacturer" -value $CPUInfo.Manufacturer 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "CPU_NumberOfCores" -value $CPUInfo.NumberOfCores 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "CPU_L2CacheSize" -value $CPUInfo.L2CacheSize 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "CPU_L3CacheSize" -value $CPUInfo.L3CacheSize 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "CPU_SocketDesignation" -value $CPUInfo.SocketDesignation 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "OS_Name" -value $OSInfo.Caption 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "OS_Version" -value $OSInfo.Version 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "TotalPhysical_Memory_GB" -value $PhysicalMemory 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "TotalVirtual_Memory_MB" -value $OSTotalVirtualMemory 
Add-Member -inputObject $infoObject -memberType NoteProperty -name "TotalVisable_Memory_MB" -value $OSTotalVisibleMemory 
$infoObject 
} | Select-Object * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName | Export-Csv -path c:\temp\Server_Inventory_$((Get-Date).ToString('MM-dd-yyyy')).csv # -NoTypeInformation results in csv file.