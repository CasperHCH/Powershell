#Check if EventLog exist, if it does, add event, of it doesnt, create EventLog and add event
#Create an Event Log, within a new Tree called 

#Used Variables
$LogSourceName = 
$LogDisplayName = 
$logFileExists = Get-EventLog -list | Where-Object {$_.logdisplayname -eq }

 
if (! $logFileExists) 
    {
    New-EventLog -LogName  -Source 
    }
    Else
        {
        Write-EventLog -LogName  -Source  -EventID 0001 -EntryType Information -Message  -Category 1 -RawData 10,20
        }
