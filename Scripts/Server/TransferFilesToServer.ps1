$ComputerName = read-host "Please provide Computer Name to transfer files to"
$session = New-PSSession -ComputerName $ComputerName
$container = read-host "Provide the path from where the files should be copied from - e.g. c:\temp\"
$destination = read-host "Provide the path where the files should be copied to - e.g. c:\temp\"
Copy-Item -path $container -Recurse -Destination $destination -ToSession $session
