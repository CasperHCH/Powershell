if((Get-WindowsOptionalFeature -FeatureName "IIS-ManagementConsole" -Online).State -eq "Enabled") {
  Write-Host "IIS-ManagementConsole is Installed"
  # (simplified function to paste here)
  } else {
    Write-Host "Installing IIS-ManagementConsole"
    Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ManagementConsole" -All
}

if((Get-WindowsOptionalFeature -FeatureName "IIS-ManagementService" -Online).State -eq "Enabled") {
  Write-Host "IIS-ManagementService is Installed"
  # (simplified function to paste here)
  } else {
    Write-Host "Installing IIS-ManagementService"
    Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ManagementService" -All
}
