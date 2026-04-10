# Install IIS and Common Gateway Interface features
[CmdletBinding(SupportsShouldProcess)]
param()

$features = @(
    "IIS-WebServerRole",
    "IIS-WebServer",
    "IIS-CommonHttpFeatures",
    "IIS-CGI"
)

foreach ($feature in $features) {
    $featureState = (Get-WindowsOptionalFeature -FeatureName $feature -Online).State

    if ($featureState -eq "Enabled") {
        Write-Host "$feature is already enabled" -ForegroundColor Green
    } else {
        Write-Host "Enabling $feature..." -ForegroundColor Yellow
        if ($PSCmdlet.ShouldProcess($feature, "Enable Windows optional feature")) {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
            Write-Host "$feature enabled successfully" -ForegroundColor Green
        }
    }
}
