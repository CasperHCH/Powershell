$ComputerName = read-host 
$session = New-PSSession -ComputerName $ComputerName
$container = read-host 
$destination = read-host 
Copy-Item -path $container -Recurse -Destination $destination -ToSession $session
