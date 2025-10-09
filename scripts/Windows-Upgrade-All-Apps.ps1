<#
.SYNOPSIS
    Updates all Windows apps using Winget package manager
.DESCRIPTION 
    This script automatically discovers and upgrades all available Windows applications
    using the Windows Package Manager (winget). Please read and acknowledge the disclaimer.
.NOTES
    Requires Windows Package Manager (winget) to be installed
    Author: PowerShell Scripts Collection
    Last Modified: October 2025
#>

[CmdletBinding()]
param()

# Display disclaimer with proper formatting
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "SOFTWARE DISCLAIMER: NO IMPLIED WARRANTY" -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "By using this software, you acknowledge and agree to the following terms:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. No Warranty: " -ForegroundColor Yellow -NoNewline
Write-Host "This software is provided 'as-is' without warranties of any kind."
Write-Host ""
Write-Host "2. Use at Your Own Risk: " -ForegroundColor Yellow -NoNewline  
Write-Host "The authors shall not be liable for any damages arising from use."
Write-Host ""
Write-Host "3. No Support: " -ForegroundColor Yellow -NoNewline
Write-Host "No support, maintenance, or updates may be provided."
Write-Host ""
Write-Host "4. Compliance: " -ForegroundColor Yellow -NoNewline
Write-Host "Ensure your use complies with applicable laws and regulations."
Write-Host ""
Write-Host "If you do not agree with these terms, please exit now." -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Yellow

$confirm = Read-Host "`nDo you accept these terms and wish to continue? (y/N)"
if ($confirm -notmatch '^[yY]') {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit 0
}

Write-Host "`n🚀 Starting Windows App Upgrade Process..." -ForegroundColor Green

# Function to find Winget executable
function Find-WingetPath {
    try {
        # First try the standard command
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            return "winget"
        }
        
        # Fallback: search in WindowsApps folder
        Write-Host "Searching for winget in WindowsApps folder..." -ForegroundColor Yellow
        $wingetPaths = Get-ChildItem "C:\Program Files\WindowsApps" -Recurse -File -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -eq 'winget.exe' -and $_.FullName -match 'Microsoft.DesktopAppInstaller' } |
            Sort-Object LastWriteTime -Descending
            
        if ($wingetPaths) {
            return $wingetPaths[0].FullName
        }
        
        throw "Winget executable not found"
    } catch {
        throw "Failed to locate winget: $($_.Exception.Message)"
    }
}

# Main execution
try {
    # Find winget executable
    Write-Host "📍 Locating Windows Package Manager (winget)..." -ForegroundColor Cyan
    $wingetPath = Find-WingetPath
    Write-Host "✅ Found winget at: $wingetPath" -ForegroundColor Green
    
    # Display version information
    Write-Host "`n📋 Winget Version Information:" -ForegroundColor Cyan
    & $wingetPath --info
    
    # Update package sources
    Write-Host "`n🔄 Updating package sources..." -ForegroundColor Cyan
    & $wingetPath source update
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Package sources updated successfully" -ForegroundColor Green
    } else {
        Write-Warning "Package source update returned exit code: $LASTEXITCODE"
    }
    
    # List available upgrades first
    Write-Host "`n📦 Checking for available upgrades..." -ForegroundColor Cyan
    & $wingetPath upgrade
    
    # Perform upgrades
    Write-Host "`n⬆️  Starting upgrade process..." -ForegroundColor Cyan
    & $wingetPath upgrade --all --silent --accept-source-agreements --accept-package-agreements
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n🎉 All upgrades completed successfully!" -ForegroundColor Green
    } else {
        Write-Warning "Upgrade process completed with exit code: $LASTEXITCODE"
    }
    
} catch {
    Write-Error "❌ Failed to complete upgrade process: $($_.Exception.Message)"
    exit 1
}