$ComputerName = read-host 
$session = New-PSSession -ComputerName $ComputerName
$container = read-host 
$Destination = read-host 
Copy-Item $Container -Recurse -Destination $destination -FromSession $session
