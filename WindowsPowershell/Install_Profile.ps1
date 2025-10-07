Invoke-RestMethod "https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1" | Invoke-Expression

# Append contents of local profile.ps1 to the current user's all-hosts profile, avoiding duplication
$sourceProfile = "C:\PS\WindowsPowerShell\profile.ps1"
$destProfile = $PROFILE.CurrentUserAllHosts

if (Test-Path $sourceProfile) {
    $contentToAppend = Get-Content $sourceProfile -Raw

    if (!(Test-Path $destProfile)) {
        # Create the destination profile file if it doesn't exist
        New-Item -ItemType File -Path $destProfile -Force | Out-Null
    }

    $destContent = Get-Content $destProfile -Raw

    if ($destContent -notmatch [regex]::Escape($contentToAppend.Trim())) {
        Add-Content -Path $destProfile -Value "`n# --- Appended from $sourceProfile ---`n$contentToAppend"
        Write-Host "Appended contents of $sourceProfile to $destProfile"
    } else {
        Write-Host "Content from $sourceProfile already exists in $destProfile. No changes made."
    }
} else {
    Write-Warning "Source profile file not found: $sourceProfile"
}