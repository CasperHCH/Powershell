$path = 'c:\Users\cach91\Desktop\Powershell-main\scripts\SCCM\SCCMSoftwareCollectionConsolidation.ps1'
$lines = Get-Content -Path $path
for ($i = 8200; $i -le 8425; $i++) {
    $line = if ($i -lt $lines.Count) { $lines[$i] } else { '' }
    Write-Host ('{0}: {1}' -f ($i + 1), $line)
}
$all = Get-Content -Path $path -Raw
$open = ($all.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$close = ($all.ToCharArray() | Where-Object { $_ -eq '}' }).Count
Write-Host "Open:$open Close:$close"
