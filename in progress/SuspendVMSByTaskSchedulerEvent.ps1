#Used Variables for EventLog
$LogSourceName = 
$LogDisplayName = 
$logFileExists = Get-EventLog -list | Where-Object {$_.logdisplayname -eq }

#Check if EventLog exist, if it does, add event, of it doesnt, create EventLog and add event
#Create an Event Log, within a new Tree called  
#Create function to add information to an Event Log
function AddInformationToLog(){
if (! $logFileExists) #Checking if Log exist
    {
    #Log didnt exist, create it, and add entry
    New-EventLog -LogName  -Source 
    Write-EventLog -LogName  -Source  -EventID 0100 -EntryType Information -Message  -Category 1 -RawData 10,20
    }
    Else
        {
        #Add entry within Information
        Write-EventLog -LogName  -Source  -EventID 0200 -EntryType Information -Message  -Category 1 -RawData 10,20
        Write-Host 
        }
}


#End ForEach
}#End Function

SuspendVMs
