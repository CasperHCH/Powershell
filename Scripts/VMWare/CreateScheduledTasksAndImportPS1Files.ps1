<#
.SYNOPSIS
    Create scheduled tasks and copy VMware PowerShell scripts
.DESCRIPTION
    This script creates scheduled tasks from XML files and copies PowerShell scripts to VMware Workstation directory.
.PARAMETER XmlPath1
    Path to the first XML task definition file
.PARAMETER TaskName1
    Name for the first scheduled task
.PARAMETER XmlPath2
    Path to the second XML task definition file (optional)
.PARAMETER TaskName2
    Name for the second scheduled task (optional)
.PARAMETER ScriptPath1
    Path to the first PowerShell script to copy
.PARAMETER ScriptPath2
    Path to the second PowerShell script to copy
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$XmlPath1,
    [Parameter(Mandatory=$true)]
    [string]$TaskName1,
    [string]$XmlPath2,
    [string]$TaskName2,
    [string]$ScriptPath1,
    [string]$ScriptPath2
)

try {
    # Create first scheduled task
    if (Test-Path $XmlPath1) {
        Write-Host "Creating scheduled task: $TaskName1" -ForegroundColor Cyan
        schtasks.exe /create /xml $XmlPath1 /tn $TaskName1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Task '$TaskName1' created successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to create task '$TaskName1'" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ XML file not found: $XmlPath1" -ForegroundColor Red
    }

    # Create second scheduled task (if provided)
    if ($XmlPath2 -and $TaskName2) {
        if (Test-Path $XmlPath2) {
            Write-Host "Creating scheduled task: $TaskName2" -ForegroundColor Cyan
            schtasks.exe /create /xml $XmlPath2 /tn $TaskName2
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Task '$TaskName2' created successfully" -ForegroundColor Green
            } else {
                Write-Host "❌ Failed to create task '$TaskName2'" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ XML file not found: $XmlPath2" -ForegroundColor Red
        }
    }

    # Create VMware Workstation directory and copy scripts
    $vmwarePath = 'C:\Program Files\VM Workstation'
    if (-not (Test-Path $vmwarePath)) {
        New-Item -ItemType Directory $vmwarePath -Force | Out-Null
        Write-Host "📁 Created directory: $vmwarePath" -ForegroundColor Yellow
    }

    # Copy PowerShell scripts if provided
    if ($ScriptPath1 -and (Test-Path $ScriptPath1)) {
        Copy-Item $ScriptPath1 -Destination $vmwarePath -Force
        Write-Host "📄 Copied script: $ScriptPath1" -ForegroundColor Green
    }

    if ($ScriptPath2 -and (Test-Path $ScriptPath2)) {
        Copy-Item $ScriptPath2 -Destination $vmwarePath -Force
        Write-Host "📄 Copied script: $ScriptPath2" -ForegroundColor Green
    }

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
