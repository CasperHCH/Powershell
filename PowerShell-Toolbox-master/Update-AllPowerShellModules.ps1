# https://itpro-tips.com/2020/update-all-powershell-modules-at-once/
# https://itpro-tips.com/2020/mettre-a-jour-tous-les-modules-powershell-en-une-fois/

# This script provides informations about the module version (current and the latest available on PowerShell Gallery) and update to the latest version
# If you have a module with two or more versions, the script delete them and reinstall only the latest.

# PowerShell 5.0 for PowerShell Gallery
#Requires -Version 5.0
#Requires -RunAsAdministrator

Write-Host -ForegroundColor cyan 'Define PowerShell to use TLS1.2 in this session, needed since 1st April 2020 (https://devblogs.microsoft.com/powershell/powershell-gallery-tls-support/)'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# if needed, register PSGallery
# Register PSGallery PSprovider and set as Trusted source
# Register-PSRepository -Default -ErrorAction SilentlyContinue
# Set-PSRepository -Name PSGallery -InstallationPolicy trusted -ErrorAction SilentlyContinue

Write-Host -ForegroundColor Cyan

$modules = Get-InstalledModule

foreach ($module in $modules.Name) {
    $currentVersion = $null

    try {
        $currentVersion = (Get-InstalledModule -Name $module -AllVersions -ErrorAction Stop).Version
    }
    catch {
        Write-Host -ForegroundColor red
        continue
    }

    $moduleInfos = Find-Module -Name $module

    if ($null -eq $currentVersion) {
        Write-Host -ForegroundColor Cyan

        try {
            Install-Module -Name $module -Force
        }
        catch {
            Write-Host -ForegroundColor Red
        }
    }
    elseif ($moduleInfos.Version -eq $currentVersion) {
        Write-Host -ForegroundColor Green
    }
    elseif ($currentVersion.count -gt 1) {
        Write-Warning
        Write-Host -ForegroundColor Cyan

        try {
            $oldVersions = Get-InstalledModule -Name $module -AllVersions -ErrorAction Stop | Where-Object { $_.Version -ne $moduleInfos.Version }

            foreach ($oldVersion in $oldVersions) {
                Write-Host -ForegroundColor Cyan
                Remove-Module $module -ErrorAction SilentlyContinue
                Uninstall-Module $oldVersion -Force
            }

        }
        catch {
            Write-Host -ForegroundColor red
        }

        if ($moduleInfos.Version -ne $currentVersion) {
            Write-Host -ForegroundColor Cyan

            try {
                Install-Module -Name $module -Force
            }
            catch {
                Write-Host -ForegroundColor red
            }
        }
    }
    else {
        Write-Host -ForegroundColor Cyan
        try {
            Update-Module -Name $module -Force
        }
        catch {
            Write-Host -ForegroundColor red
        }
    }
}
