<#
.SYNOPSIS
    Compare Ivanti CMDB and SCCM records from a unified inventory dataset.

.DESCRIPTION
    Reads the output from Get-EpmUnifiedInventory.ps1 and produces focused reconciliation
    reports for operations and governance.

.PARAMETER UnifiedInventoryPath
    Path to unified inventory CSV or JSON.

.PARAMETER OutputPath
    Folder where reconciliation reports are written.

.EXAMPLE
    .\Compare-EpmCmdbVsSccm.ps1 -UnifiedInventoryPath .\output\UnifiedInventory_20260325_080000.csv

.NOTES
    SECURITY CLASSIFICATION: INTERNAL
    DATA HANDLING: Endpoint inventory metadata only.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$UnifiedInventoryPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $PSScriptRoot "output")
)

$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogPath = Join-Path $PSScriptRoot "Compare-EpmCmdbVsSccm.log"

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$script:SessionId] [$Level] $Message"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        default { "White" }
    }

    Write-Host $line -ForegroundColor $color
    Add-Content -Path $script:LogPath -Value $line
}

function Get-InventoryData {
    param([string]$Path)

    $extension = [IO.Path]::GetExtension($Path)
    switch ($extension.ToLowerInvariant()) {
        ".csv" { return Import-Csv -Path $Path }
        ".json" {
            $raw = Get-Content -Path $Path -Raw
            return $raw | ConvertFrom-Json
        }
        default {
            throw "Unsupported file type '$extension'. Provide CSV or JSON."
        }
    }
}

function Test-ValueMismatch {
    param(
        [string]$ValueA,
        [string]$ValueB
    )

    if ([string]::IsNullOrWhiteSpace($ValueA) -or [string]::IsNullOrWhiteSpace($ValueB)) {
        return $false
    }

    return -not ($ValueA.Trim().ToUpperInvariant() -eq $ValueB.Trim().ToUpperInvariant())
}

try {
    Write-Log -Message "Starting CMDB vs SCCM reconciliation" -Level "INFO"

    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $data = Get-InventoryData -Path $UnifiedInventoryPath
    if (-not $data -or $data.Count -eq 0) {
        throw "No records found in unified inventory file: $UnifiedInventoryPath"
    }

    $inSccmNotInCmdb = $data | Where-Object { $_.InSccm -eq $true -and $_.InIvantiCmdb -eq $false }
    $inCmdbNotInSccm = $data | Where-Object { $_.InIvantiCmdb -eq $true -and $_.InSccm -eq $false }

    $ownerMismatch = $data | Where-Object {
        $_.InIvantiCmdb -eq $true -and
        $_.InSccm -eq $true -and
        (Test-ValueMismatch -ValueA $_.OwnerIvanti -ValueB $_.OwnerSccm)
    }

    $siteMismatch = $data | Where-Object {
        $_.InIvantiCmdb -eq $true -and
        $_.InSccm -eq $true -and
        (Test-ValueMismatch -ValueA $_.SiteIvanti -ValueB $_.SiteSccm)
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $missingCmdbPath = Join-Path $OutputPath "CmdbVsSccm_InSccmNotInCmdb_$timestamp.csv"
    $missingSccmPath = Join-Path $OutputPath "CmdbVsSccm_InCmdbNotInSccm_$timestamp.csv"
    $ownerMismatchPath = Join-Path $OutputPath "CmdbVsSccm_OwnerMismatch_$timestamp.csv"
    $siteMismatchPath = Join-Path $OutputPath "CmdbVsSccm_SiteMismatch_$timestamp.csv"
    $summaryPath = Join-Path $OutputPath "CmdbVsSccm_Summary_$timestamp.md"

    $inSccmNotInCmdb | Export-Csv -Path $missingCmdbPath -NoTypeInformation -Encoding UTF8
    $inCmdbNotInSccm | Export-Csv -Path $missingSccmPath -NoTypeInformation -Encoding UTF8
    $ownerMismatch | Export-Csv -Path $ownerMismatchPath -NoTypeInformation -Encoding UTF8
    $siteMismatch | Export-Csv -Path $siteMismatchPath -NoTypeInformation -Encoding UTF8

    $summaryLines = @(
        "# CMDB vs SCCM Reconciliation Summary",
        "",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Source: $UnifiedInventoryPath",
        "",
        "## Counts",
        "- Total records reviewed: $($data.Count)",
        "- In SCCM not in CMDB: $($inSccmNotInCmdb.Count)",
        "- In CMDB not in SCCM: $($inCmdbNotInSccm.Count)",
        "- Owner mismatches: $($ownerMismatch.Count)",
        "- Site mismatches: $($siteMismatch.Count)",
        "",
        "## Output Files",
        "- $missingCmdbPath",
        "- $missingSccmPath",
        "- $ownerMismatchPath",
        "- $siteMismatchPath"
    )
    $summaryLines | Set-Content -Path $summaryPath -Encoding UTF8

    Write-Host "`nReconciliation summary:" -ForegroundColor Cyan
    Write-Host " - Total records reviewed: $($data.Count)" -ForegroundColor White
    Write-Host " - In SCCM not in CMDB: $($inSccmNotInCmdb.Count)" -ForegroundColor White
    Write-Host " - In CMDB not in SCCM: $($inCmdbNotInSccm.Count)" -ForegroundColor White
    Write-Host " - Owner mismatches: $($ownerMismatch.Count)" -ForegroundColor White
    Write-Host " - Site mismatches: $($siteMismatch.Count)" -ForegroundColor White

    Write-Host "`nOutputs:" -ForegroundColor Cyan
    Write-Host " - $missingCmdbPath" -ForegroundColor White
    Write-Host " - $missingSccmPath" -ForegroundColor White
    Write-Host " - $ownerMismatchPath" -ForegroundColor White
    Write-Host " - $siteMismatchPath" -ForegroundColor White
    Write-Host " - $summaryPath" -ForegroundColor White

    Write-Log -Message "CMDB vs SCCM reconciliation completed" -Level "INFO"
}
catch {
    Write-Log -Message "CMDB vs SCCM reconciliation failed: $($_.Exception.Message)" -Level "ERROR"
    throw
}
