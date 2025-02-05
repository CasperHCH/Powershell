#Variables for Domain network
$InternalNetwork = , 

#Variable for current network profile
$Network = Get-NetConnectionProfile

#Check if EventLog exist, if it does, add event, of it doesnt, create EventLog and add event
#Create an Event Log, within a new Tree called 

#Used cheking if eventlog exist, if not create it
$logFileExists = Get-EventLog -list | Where-Object {$_.logdisplayname -eq } 
if (! $logFileExists) {
    New-EventLog -LogName  -Source 
} 

#Create function to add information to an Event Log
function AddInformationToLog(){
#Add entry within Information
Write-EventLog -LogName  -Source  -EventID 0001 -EntryType Information -Message $($LogInformationMessage) -Category 1 -RawData 10,20
Write-Host 
}


#End ForEach
    }# End IF
Else{#Start Else
        $LogInformationMessage = 
        AddInformationToLog()
        Write-Host 
    }#End Else
}#End Function


CheckNetwork
