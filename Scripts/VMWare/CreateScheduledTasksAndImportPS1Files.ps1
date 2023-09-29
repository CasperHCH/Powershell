schtasks.exe /create /xml "C:\Program Files\VM Workstation\Suspend All WM's at Restart or Logof or User Switching.xml" /tn "\VM Workstation\Suspend All WM's at Restart or Logof or User Switching"
schtasks.exe /create /xml "C:\Program Files\VM Workstation\Suspend VMS If Network EQ Domain.xml" /tn "\VM Workstation\Suspend VMS If Network EQ Domain"

#if(-not (Test-Path 'C:\Program Files\VM Workstation')){New-Item -ItemType dir 'C:\Program Files\VM Workstation'}
#
#Copy-Item "C:\Temp\VMWARE - Workstation\SuspendVMSByTaskSchedulerEvent.ps1" -Destination 'C:\Program Files\VM Workstation'
#Copy-Item "C:\Temp\VMWARE - Workstation\SuspendVMSIfNetworkEQDomain.ps1" -Destination 'C:\Program Files\VM Workstation'