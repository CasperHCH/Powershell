#Check if EventLog exist, if it does, add event, of it doesnt, create EventLog and add event
#Create an Event Log, within a new Tree called "VMware Virtual Machine"

#Used Variables
$LogSourceName = "VMware Workstation Player"
$LogDisplayName = "SuspendVMSIfNetworkEQDomain.ps1"
$logFileExists = Get-EventLog -list | Where-Object {$_.logdisplayname -eq "$LogDisplayName"}

 
if (! $logFileExists) 
    {
    New-EventLog -LogName "$LogDisplayName" -Source "$LogSourceName"
    }
    Else
        {
        Write-EventLog -LogName "$LogDisplayName" -Source "$LogSourceName" -EventID 0001 -EntryType Information -Message "MyApp added a user-requested feature to the display." -Category 1 -RawData 10,20
        }