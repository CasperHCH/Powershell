<#
.SYNOPSIS
    Install IIS Web Server Role and Management Tools
.DESCRIPTION
    This script installs IIS Web Server Role and IIS Management Console on Windows.
.NOTES
    Requires administrator privileges and Windows Features capability.
#>

#Requires -RunAsAdministrator

$IISFeatures = @(
    "IIS-WebServerRole",
    "IIS-WebServer",
    "IIS-CommonHttpFeatures",
    "IIS-HttpErrors",
    "IIS-HttpLogging",
    "IIS-RequestFiltering",
    "IIS-StaticContent",
    "IIS-DefaultDocument",
    "IIS-DirectoryBrowsing",
    "IIS-ManagementConsole"
)

Write-Host "Installing IIS Web Server and Management Tools..." -ForegroundColor Cyan

foreach ($feature in $IISFeatures) {
    try {
        $featureState = (Get-WindowsOptionalFeature -FeatureName $feature -Online -ErrorAction Stop).State

        if($featureState -eq "Enabled") {
            Write-Host "✅ $feature is already enabled" -ForegroundColor Green
        } else {
            Write-Host "⚙️  Installing $feature..." -ForegroundColor Yellow
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart | Out-Null
            Write-Host "✅ $feature installed successfully" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Error installing $feature`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🎉 IIS installation complete!" -ForegroundColor Green
Write-Host "💡 You can now access IIS Manager or browse to http://localhost" -ForegroundColor Cyan
