$ComputerName = read-host "Please provide Computer Name to transfer files to"
$session = New-PSSession -ComputerName $ComputerName
$container = read-host "Provide the path to be copied from - e.g. C:\Temp"
$Destination = read-host "Provide the Destination folder - e.g. C:\Temp"
Copy-Item $Container -Recurse -Destination $destination -FromSession $session
