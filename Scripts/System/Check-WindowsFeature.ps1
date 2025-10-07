function Check-WindowsFeature {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)] [string]$FeatureName
    )

    try {
        $Feature = Get-WindowsOptionalFeature -FeatureName $FeatureName -Online -ErrorAction Stop

        if($Feature.State -eq "Enabled") {
            Write-Host "✅ Windows Feature '$FeatureName' is ENABLED" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Windows Feature '$FeatureName' is DISABLED" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "⚠️ Error checking Windows Feature '$FeatureName': $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Example usage
if ($args.Count -eq 0) {
    $FeatureName = Read-Host "Enter Windows Feature name to check"
    Check-WindowsFeature -FeatureName $FeatureName
} else {
    Check-WindowsFeature -FeatureName $args[0]
}
