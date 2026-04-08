# SCCM Script Index

This index summarizes SCCM automation scripts in this folder.

## Notes
- Run site-level scripts from a host with the Configuration Manager console module installed.
- Most report scripts are read-only.
- Remediation scripts support safety features such as `-WhatIf` where applicable.

## WhatIf Support (Quick Reference)
- All SCCM scripts in this folder now expose `-WhatIf` via `SupportsShouldProcess`.
- Scripts that perform changes (`remove`, `update`, `redistribute`, `trigger`, `repair`) honor `-WhatIf` as an execution preview.
- Read-only/report scripts also accept `-WhatIf` for consistency; because they do not perform state changes, behavior is generally unchanged.
- `-DryRun` note: legacy `-DryRun` parameters are retained only where already present (`SCCM-EnrichSoftwareMetadata.ps1` and `SCCMSoftwareCollectionConsolidation.ps1`) for backward compatibility; `-WhatIf` is the standard going forward.

## Dependency Requirement (Important)
- The scripts listed below that dot-source `SCCM-Common.ps1` require that file to exist in the same folder (`$PSScriptRoot`) at runtime.
- If `SCCM-Common.ps1` is missing, these scripts will fail immediately before main execution.
- When copying scripts to another machine, copy `SCCM-Common.ps1` together with any dependent SCCM script.
- Recommended approach: copy or clone the full `scripts/SCCM` folder rather than individual files.

Dependent scripts include:
- `SCCM-AnalyzeStaleCollectionsAndDeployments.ps1`
- `SCCM-AuditApplicationSupersedence.ps1`
- `SCCM-BoundaryGroupAudit.ps1`
- `SCCM-CollectClientLogs.ps1`
- `SCCM-CollectionMembershipDriftReport.ps1`
- `SCCM-DeploymentFailureReport.ps1`
- `SCCM-EnableWakeOnLanForUninstallDeployments.ps1`
- `SCCM-RedistributeFailedContent.ps1`
- `SCCM-ReferenceImpactAnalysis.ps1`
- `SCCM-RepairClientHealth.ps1`
- `SCCM-RetryFailedDeployments.ps1`
- `SCCM-SoftwareUpdateComplianceReport.ps1`
- `SCCM-TestClientHealth.ps1`
- `SCCM-ValidateContentDistribution.ps1`

## Shared Helper

### SCCM-Common.ps1
- Purpose: Shared helper functions for logging, audit records, output path handling, safe object access, and SCCM site connection helpers.
- Key inputs: None (dot-source from other scripts).
- Example:
```powershell
. .\SCCM-Common.ps1
$ctx = Initialize-SccmScript -ScriptName 'Example.ps1'
```

## Client Health

### SCCM-TestClientHealth.ps1
- Purpose: Tests SCCM client health on one or more devices and exports report output.
- Key inputs: `-ComputerName`, `-MaxLogAgeHours`, `-OutputDirectory`, `-ExportJson`.
- Example:
```powershell
.\SCCM-TestClientHealth.ps1 -ComputerName PC001,PC002 -ExportJson
```

### SCCM-RepairClientHealth.ps1
- Purpose: Applies common client remediation actions (service restart, policy reset, schedule triggers, optional ccmrepair).
- Key inputs: `-ComputerName`, `-RestartClientService`, `-ResetClientPolicy`, `-TriggerStandardSchedules`, `-RunCcmRepair`.
- Example:
```powershell
.\SCCM-RepairClientHealth.ps1 -ComputerName PC001 -RestartClientService -TriggerStandardSchedules -WhatIf
```

## Deployment Failure and Retry

### SCCM-DeploymentFailureReport.ps1
- Purpose: Builds deployment failure summaries and optional asset detail output.
- Key inputs: `-SiteCode`, `-DeploymentName`, `-CollectionName`, `-IncludeAssetDetails`, `-OutputDirectory`.
- Example:
```powershell
.\SCCM-DeploymentFailureReport.ps1 -SiteCode P01 -IncludeAssetDetails
```

### SCCM-RetryFailedDeployments.ps1
- Purpose: Retries failed deployment scenarios by triggering client-side evaluation schedules on target devices.
- Key inputs: `-InputCsvPath`, `-ComputerName`, trigger switches, `-DelaySeconds`.
- Example:
```powershell
.\SCCM-RetryFailedDeployments.ps1 -InputCsvPath .\output\SCCM-DeploymentFailureDetails.csv -WhatIf
```

### SCCM-EnableWakeOnLanForUninstallDeployments.ps1
- Purpose: Bulk-enables wake-up packets on uninstall application deployments.
- Key inputs: `-SiteCode`, `-ApplicationName`, `-CollectionName`, `-AssignmentId`, `-IncludeDisabled`.
- Example:
```powershell
.\SCCM-EnableWakeOnLanForUninstallDeployments.ps1 -SiteCode P01 -WhatIf
```

## Update Compliance and Content Distribution

### SCCM-SoftwareUpdateComplianceReport.ps1
- Purpose: Exports software update compliance summary and detail reports.
- Key inputs: `-SiteCode`, `-CollectionName`, `-DeploymentName`, `-OutputDirectory`.
- Example:
```powershell
.\SCCM-SoftwareUpdateComplianceReport.ps1 -SiteCode P01 -CollectionName Workstations
```

### SCCM-ValidateContentDistribution.ps1
- Purpose: Validates content distribution status and highlights failed or in-progress package distribution.
- Key inputs: `-SiteCode`, `-ContentName`, `-PackageId`, `-IncludeHealthyContent`, `-OutputDirectory`.
- Example:
```powershell
.\SCCM-ValidateContentDistribution.ps1 -SiteCode P01
```

### SCCM-RedistributeFailedContent.ps1
- Purpose: Redistributes failed package content to one or more distribution points.
- Key inputs: `-SiteCode`, `-InputCsvPath`, `-PackageId`, `-DistributionPointName`.
- Example:
```powershell
.\SCCM-RedistributeFailedContent.ps1 -PackageId P0100123 -DistributionPointName dp01.contoso.com -WhatIf
```

## Governance and Impact Analysis

### SCCM-AnalyzeStaleCollectionsAndDeployments.ps1
- Purpose: Flags stale collections and deployments based on age, membership, and linkage checks.
- Key inputs: `-SiteCode`, `-InactiveDays`, `-OutputDirectory`.
- Example:
```powershell
.\SCCM-AnalyzeStaleCollectionsAndDeployments.ps1 -SiteCode P01 -InactiveDays 120
```

### SCCM-BoundaryGroupAudit.ps1
- Purpose: Audits boundary groups, boundaries, and site-system linkage gaps.
- Key inputs: `-SiteCode`, `-OutputDirectory`.
- Example:
```powershell
.\SCCM-BoundaryGroupAudit.ps1 -SiteCode P01
```

### SCCM-ReferenceImpactAnalysis.ps1
- Purpose: Reports reference impact for applications, packages, and collections before cleanup or change.
- Key inputs: `-SiteCode`, `-ApplicationName`, `-PackageId`, `-CollectionName`, `-OutputDirectory`.
- Example:
```powershell
.\SCCM-ReferenceImpactAnalysis.ps1 -SiteCode P01 -ApplicationName Firefox
```

### SCCM-AuditApplicationSupersedence.ps1
- Purpose: Audits multi-version application families for supersedence signal gaps requiring review.
- Key inputs: `-SiteCode`, `-ApplicationName`, `-OutputDirectory`.
- Example:
```powershell
.\SCCM-AuditApplicationSupersedence.ps1 -SiteCode P01
```

### SCCM-CollectionMembershipDriftReport.ps1
- Purpose: Exports collection membership snapshot and optional drift report versus a baseline CSV.
- Key inputs: `-SiteCode`, `-CollectionName`, `-BaselineCsvPath`, `-OutputDirectory`.
- Example:
```powershell
.\SCCM-CollectionMembershipDriftReport.ps1 -SiteCode P01 -CollectionName Firefox -BaselineCsvPath .\baseline.csv
```

## Client Diagnostics

### SCCM-CollectClientLogs.ps1
- Purpose: Collects common SCCM client logs from one or more devices and optionally compresses bundles.
- Key inputs: `-ComputerName`, `-LogName`, `-OutputDirectory`, `-Compress`.
- Example:
```powershell
.\SCCM-CollectClientLogs.ps1 -ComputerName PC001,PC002 -Compress
```

### SCCM-RunClientActionsLocal.ps1
- Purpose: Triggers standard local SCCM client action schedules on the local machine.
- Key inputs: `-DelaySeconds`, `-ContinueOnError`, `-IncludeOptionalActions`, `-PassThru`.
- Example:
```powershell
.\SCCM-RunClientActionsLocal.ps1 -WhatIf
```

## Collection Analysis and Cleanup

### SCCM-CollectionAnalyse.ps1
- Purpose: Performs read-only collection consolidation and safe-to-delete analysis.
- Key inputs: `-SiteCode`, `-AnalyzeConsolidation`, `-AnalyzeSafeToDelete`, `-AnalyzeAll`, `-Mode`, `-OutputCsv`, `-JsonSummaryPath`.
- Example:
```powershell
.\SCCM-CollectionAnalyse.ps1 -SiteCode P01 -AnalyzeAll -Mode Deep
```

### SCCM-DeleteWinFolderIfSoftwareIsntPresent.ps1
- Purpose: Identifies local software folders not represented in SCCM and can remove orphaned folders.
- Key inputs: `-SCCMSiteServer`, `-SCCMSiteCode`, `-WindowsSoftwareBasePath`, `-MinimumFolderAgeDays`, `-ExcludeFolders`.
- Example:
```powershell
.\SCCM-DeleteWinFolderIfSoftwareIsntPresent.ps1 -SCCMSiteServer sccm-01.contoso.com -SCCMSiteCode P01 -WhatIf
```

## Software Metadata and Version Intelligence

### SCCM-EnrichSoftwareMetadata.ps1
- Purpose: Enriches missing SCCM application metadata such as publisher and software version.
- Key inputs: `-SiteCode`, `-SoftwareName`, `-IncludeAllApplications`, `-VendorMapPath`, `-DryRun`, `-ReportPath`.
- Example:
```powershell
.\SCCM-EnrichSoftwareMetadata.ps1 -SiteCode P01 -SoftwareName Firefox -DryRun
```

### SCCM-SoftwareVersionAudit.ps1
- Purpose: Exports SCCM application inventory and compares current vs latest public versions.
- Key inputs: `-SiteCode`, `-SoftwareName`, `-IncludeAllApplications`, `-ExportOnly`, `-InputCsvPath`, `-OutputDirectory`, `-ExportVendorMap`, `-ExportUnresolvedReport`.
- Example:
```powershell
.\SCCM-SoftwareVersionAudit.ps1 -SiteCode P01 -IncludeAllApplications -ExportOnly
```

## Legacy / Specialized

### SCCMSoftwareCollectionConsolidation.ps1
- Purpose: Legacy all-in-one collection consolidation workflow script.
- Note: This script contains its own helper functions (for example internal site connection helpers) and does not dot-source `SCCM-Common.ps1`.
- Example:
```powershell
.\SCCMSoftwareCollectionConsolidation.ps1 -SiteCode P01
```
