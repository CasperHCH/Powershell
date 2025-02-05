function Check-WindowsFeature {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)] [string]$FeatureName
    )
  if((Get-WindowsOptionalFeature -FeatureName $FeatureName -Online).State -eq ) {
        Write-Host $FeatureName 
        # (simplified function to paste here)
    } else {
        Write-Host  $FeatureName
    }
  }
 Check-WindowsFeature
