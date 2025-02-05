if((Get-WindowsOptionalFeature -FeatureName  -Online).State -eq ) {
  Write-Host 
  # (simplified function to paste here)
  } else {
    Write-Host 
    Enable-WindowsOptionalFeature -Online -FeatureName  -All
}

if((Get-WindowsOptionalFeature -FeatureName  -Online).State -eq ) {
  Write-Host 
  # (simplified function to paste here)
  } else {
    Write-Host 
    Enable-WindowsOptionalFeature -Online -FeatureName  -All
}
