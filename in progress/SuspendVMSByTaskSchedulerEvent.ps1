#Used Variables for EventLog
$LogSourceName = "Task Scheduler"
$LogDisplayName = "VMware Workstation Player"
$logFileExists = Get-EventLog -list | Where-Object {$_.logdisplayname -eq "$LogDisplayName"}

#Check if EventLog exist, if it does, add event, of it doesnt, create EventLog and add event
#Create an Event Log, within a new Tree called "VMware Virtual Machine" 
#Create function to add information to an Event Log
function AddInformationToLog(){
if (! $logFileExists) #Checking if Log exist
    {
    #Log didnt exist, create it, and add entry
    New-EventLog -LogName "$LogDisplayName" -Source "$LogSourceName"
    Write-EventLog -LogName "$LogDisplayName" -Source "$LogSourceName" -EventID 0100 -EntryType Information -Message "Log has now been created" -Category 1 -RawData 10,20
    }
    Else
        {
        #Add entry within Information
        Write-EventLog -LogName "$LogDisplayName" -Source "$LogSourceName" -EventID 0200 -EntryType Information -Message "$LogInformationMessage" -Category 1 -RawData 10,20
        Write-Host "Im in the Else statement, and should add a text to the log"
        }
}


Function SuspendVMs{
#Because the current user is being logged off, or the PC is being shutdown suspend all running VM's
#check if any VM exists, and list them in an array ($VMS)
$vms = Get-ChildItem -Path C:\Users -Filter "*.vmx" -Exclude *.vmxf -Recurse | select FullName, Name
#For each VM ($V) in the Array ($VMS) Suspend the VM
foreach ($v in $vms)
    {#Start Foreach
        #Suspend the VM $V
        &"C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" suspend ($v.FullName).ToString()
        #Create text for the Event Log
        $LogInformationMessage = "The following VM has been suspended: $($V.FullName)"
        #Add the text to the Event Log
        AddInformationToLog("$LogInformationMessage")
    }#End ForEach
}#End Function

SuspendVMs