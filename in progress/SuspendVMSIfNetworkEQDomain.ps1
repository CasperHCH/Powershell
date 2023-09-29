#Variables for Domain network
$InternalNetwork = "EET Group Internal", "eetnordic.net"

#Variable for current network profile
$Network = Get-NetConnectionProfile

#Check if EventLog exist, if it does, add event, of it doesnt, create EventLog and add event
#Create an Event Log, within a new Tree called "VMware Virtual Machine"

#Used cheking if eventlog exist, if not create it
$logFileExists = Get-EventLog -list | Where-Object {$_.logdisplayname -eq "VMware Workstation Player"} 
if (! $logFileExists) {
    New-EventLog -LogName "VMware Workstation Player" -Source "Suspend VMS If Network EQ Domain Script"
} 

#Create function to add information to an Event Log
function AddInformationToLog(){
#Add entry within Information
Write-EventLog -LogName "VMware Workstation Player" -Source "Suspend VMS If Network EQ Domain Script" -EventID 0001 -EntryType Information -Message $($LogInformationMessage) -Category 1 -RawData 10,20
Write-Host "Im in the AddInformationToLog Function, and should add a text to the log, text to add is: $($LogInformationMessage)"
}


Function CheckNetwork{
#Check if the PC is on domain network
if($Network.Name -in $InternalNetwork)
    {#Start IF
        $LogInformationMessage = "The PC is on Domain network named: $Network.Name"
        AddInformationToLog("$LogInformationMessage")
        #Because the PC is on Domain network, check if any VM exists, and list them in an array ($VMS)
        $vms = Get-ChildItem -Path C:\Users -Filter "*.vmx" -Exclude *.vmxf -Recurse | select FullName, Name
        Write-Host "Im in an IF statement - The PC is on Domain network named: $Network.Name"
        #For each VM ($V) in the Array ($VMS) Suspend the VM
            foreach ($v in $vms)
                {#Start Foreach
                    #Suspend the VM $V
                    &"C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" suspend ($v.FullName).ToString()
                    #Create text for the Event Log
                    $LogInformationMessage = "The following VM has been suspended: $($V.FullName)"
                    #Add the text to the Event Log
                    AddInformationToLog("$LogInformationMessage")
                    Write-Host "Im in a ForEach to suspend all running VM's - currently suspending: $($v.FullName)"
                }#End ForEach
    }# End IF
Else{#Start Else
        $LogInformationMessage = "The current Network is: $($IN), VM's has not been suspended"
        AddInformationToLog("$LogInformationMessage")
        Write-Host "Im in an Else statement - The current Network is: $($IN), VM's has not been suspended"
    }#End Else
}#End Function


CheckNetwork