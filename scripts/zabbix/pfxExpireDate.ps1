$pfxPath = "F:\PkgSource\Tools\DP\pipsdp02_23-01-2025.pfx"
$output = certutil -dump $pfxPath
$expirationDate = $output | Select-String -Pattern "NotAfter" | select -Last 1
$clean = "$($expirationDate -join ' ')" -replace "NotAfter:" -replace "  "
$clean = [datetime]::ParseExact($clean,"dd-MM-yyyy HH:ss",$null)
$clean = $clean.ToString("dd-MM-yyyy")
$date = Get-Date
$date = $date.ToString("dd-MM-yyyy")
$StartDate=(GET-DATE -Format "dd-MM-yyyy HH:mm")
$ts = NEW-TIMESPAN –Start $StartDate –End $clean
$ts.Days