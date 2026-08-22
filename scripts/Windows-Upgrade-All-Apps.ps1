<#
Simple Windows upgrade script using winget.

Usage examples:
  .\Windows-Upgrade-All-Apps.ps1 -DryRun
  .\Windows-Upgrade-All-Apps.ps1 -ExcludePackages @("Microsoft.VisualStudioCode") -CreateRestorePoint
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string[]]$ExcludePackages = @(),
    [switch]$CreateRestorePoint,
    [switch]$Force
)

function Test-IsAdmin {
    $current = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WingetPath {
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'winget not found. Install Windows Package Manager from the Microsoft Store.'
}

try {
    Write-Host "Simple winget upgrade script" -ForegroundColor Cyan

    if (-not $DryRun -and -not (Test-IsAdmin)) {
        throw 'This script must be run as Administrator unless using -DryRun.'
    }

    $winget = Get-WingetPath
    Write-Host "Using winget: $winget" -ForegroundColor Green

    # Optional confirmation
    if (-not $Force -and -not $DryRun) {
        $resp = Read-Host 'Proceed with upgrading installed packages? (y/N)'
        if ($resp -notmatch '^[yY]') { Write-Host 'Aborted.'; exit 0 }
    }

    # Update sources
    Write-Host 'Updating winget sources...' -ForegroundColor Cyan
    & $winget source update | Out-Null

    # Get upgrades (try JSON output, fall back to text)
    $upgrades = @()
    try {
        $json = & $winget upgrade --include-unknown --accept-source-agreements --output json 2>$null
        if ($json) {
            $items = $json | ConvertFrom-Json
            foreach ($it in $items) {
                $upgrades += [PSCustomObject]@{ Id = $it.Id; Name = $it.Name; Current = $it.InstalledVersion; Available = $it.AvailableVersion }
            }
        }
    }
    catch { }

    if ($upgrades.Count -eq 0) {
        # Fallback to parsing table output
        $txt = & $winget upgrade --include-unknown --accept-source-agreements 2>$null
        $lines = $txt -split "`n" | Where-Object { $_ -and ($_ -notmatch '^Name') -and ($_ -notmatch '^-+') }
        foreach ($line in $lines) {
            $cols = $line -split '\s{2,}' | ForEach-Object { $_.Trim() }
            if ($cols.Count -ge 3) {
                $avail = if ($cols.Count -ge 4) { $cols[3] } else { '' }
                $upgrades += [PSCustomObject]@{ Name = $cols[0]; Id = $cols[1]; Current = $cols[2]; Available = $avail }
            }
        }
    }

    # Filter excludes
    if ($ExcludePackages.Count -gt 0) {
        $upgrades = $upgrades | Where-Object { $_.Id -notin $ExcludePackages -and $_.Name -notin $ExcludePackages }
    }

    if ($upgrades.Count -eq 0) {
        Write-Host 'No upgrades available.' -ForegroundColor Green
        exit 0
    }

    Write-Host "Found $($upgrades.Count) upgrades:" -ForegroundColor Cyan
    $upgrades | ForEach-Object { Write-Host " - $($_.Name) ($($_.Current) -> $($_.Available))" }

    if ($DryRun) { Write-Host 'Dry run mode; no changes will be made.' -ForegroundColor Yellow; exit 0 }

    if ($CreateRestorePoint) {
        try {
            Write-Host 'Creating system restore point...' -ForegroundColor Cyan
            Checkpoint-Computer -Description "Winget Upgrades $(Get-Date -Format yyyy-MM-dd_HH-mm)" -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
            Write-Host 'Restore point created.' -ForegroundColor Green
        }
        catch { Write-Warning "Could not create restore point: $($_.Exception.Message)" }
    }

    $success = 0; $failed = 0
    foreach ($pkg in $upgrades) {
        Write-Host "Upgrading $($pkg.Name) ($($pkg.Id))..." -ForegroundColor Cyan
        $args = @('upgrade', '--id', $pkg.Id, '--accept-source-agreements', '--accept-package-agreements', '--silent')
        $out = & $winget @args 2>&1
        if ($LASTEXITCODE -eq 0) { $success++; Write-Host "  OK" -ForegroundColor Green } else { $failed++; Write-Host "  FAILED (exit $LASTEXITCODE)" -ForegroundColor Red }
    }

    Write-Host "`nSummary: $success succeeded, $failed failed." -ForegroundColor Cyan
    if ($failed -gt 0) { exit 1 } else { exit 0 }

}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}
