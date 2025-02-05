schtasks.exe /create /xml  /tn 
schtasks.exe /create /xml  /tn 

#if(-not (Test-Path 'C:\Program Files\VM Workstation')){New-Item -ItemType dir 'C:\Program Files\VM Workstation'}
#
#Copy-Item  -Destination 'C:\Program Files\VM Workstation'
#Copy-Item  -Destination 'C:\Program Files\VM Workstation'
