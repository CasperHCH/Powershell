# SECURITY WARNING: Direct execution of remote code has been disabled
# The following line downloads and executes code from GitHub which poses security risks
# Invoke-RestMethod "https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1" | Invoke-Expression
Write-Warning "Remote profile installation has been disabled for security reasons. Please review and manually execute if needed."

# Append contents of local profile.ps1 to the current user's all-hosts profile, avoiding duplication
$PSRootPath = Split-Path -Parent $PSScriptRoot
$sourceProfile = "$PSRootPath\WindowsPowerShell\profile.ps1"
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
        Write-Information "Appended contents of $sourceProfile to $destProfile" -InformationAction Continue
    } else {
        Write-Information "Content from $sourceProfile already exists in $destProfile. No changes made." -InformationAction Continue
    }
} else {
    Write-Warning "Source profile file not found: $sourceProfile"
}