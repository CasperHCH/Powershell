# Endpoint Management Automation Kit

This folder contains endpoint-manager-focused automation for environments using:
- Ivanti CMDB as the configuration source of record
- SCCM for endpoint management and software/patch operations
- Zabbix for monitoring and alerting

## Purpose

Build a practical workflow that starts with data consistency, then enables targeted remediation and governance reporting.

## MVP Flow

1. Build unified inventory:
   - Run `Get-EpmUnifiedInventory.ps1`
   - Combine Ivanti CMDB, SCCM, and Zabbix data into one normalized dataset
2. Run reconciliation:
   - Run `Compare-EpmCmdbVsSccm.ps1`
   - Generate drift/gap reports for operations and governance

## Script Backlog (Suggested Build Order)

1. `Get-EpmUnifiedInventory.ps1` (included)
2. `Compare-EpmCmdbVsSccm.ps1` (included)
3. `Compare-EpmMonitoringCoverage.ps1`
4. `Get-EpmStaleDeviceReport.ps1`
5. `Get-EpmPatchCompliance.ps1`
6. `Get-EpmEndpointProtectionStatus.ps1`
7. `Invoke-EpmClientHealthRemediation.ps1`
8. `Get-EpmSoftwareRationalization.ps1`
9. `New-EpmExecutiveKpiDataset.ps1`

## Parameter Standards

- No hardcoded domains, hosts, or credentials
- Validate URL parameters as HTTPS endpoints
- Use `SecureString` for tokens
- Place audit logs next to each script file
- Add `-WhatIf` support for any future script that changes state

## Output Conventions

- Write results to a timestamped file in `output\`
- Export both CSV and JSON for machine and analyst use
- Include a summary section in console output for quick triage

## Example Usage

```powershell
# 1) Build unified inventory from CSV exports
.\Get-EpmUnifiedInventory.ps1 \
  -Mode Csv \
  -IvantiCmdbCsvPath "C:\Data\ivanti_cmdb_export.csv" \
  -SccmCsvPath "C:\Data\sccm_devices.csv" \
  -ZabbixCsvPath "C:\Data\zabbix_hosts.csv" \
  -OrganizationDomain "example.org"

# 2) Compare Ivanti CMDB vs SCCM using the produced inventory CSV
.\Compare-EpmCmdbVsSccm.ps1 \
  -UnifiedInventoryPath ".\output\UnifiedInventory_20260325_080000.csv"
```

## Expected First Reports

- Devices in SCCM but not in CMDB
- Devices in CMDB but not in SCCM
- Devices missing Zabbix monitoring coverage
- Stale devices by age threshold
