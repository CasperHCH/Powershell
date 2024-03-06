$destfolders = "C:\Program Files\PowerShell\7\profile.ps1", "C:\Users\caschr\Documents\PowerShell\profile.ps1", "C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1"
$destfolders | ForEach-Object{Copy-Item -path "./micosoft.Powershell_profile.ps1" -destination {Join-Path $_ $destFileName}}
& $profile