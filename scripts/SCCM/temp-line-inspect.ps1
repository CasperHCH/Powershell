$path = 'c:\Users\cach91\Desktop\Powershell-main\scripts\SCCM\SCCMSoftwareCollectionConsolidation.ps1'
$line = (Get-Content -Path $path)[8268]
Write-Host "Line 8269 length: $($line.Length)"
Write-Host "Line text: [$line]"
$chars = $line.ToCharArray()
for ($i=0; $i -lt $chars.Count; $i++) {
    $code = [int][char]$chars[$i]
    Write-Host "{0}: '{1}' ({2})" -f ($i+1), $chars[$i], $code
}
