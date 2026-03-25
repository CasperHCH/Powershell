# SCCM Script Index

This index summarizes the newly added SCCM automation scripts in this folder.

## Notes
- Run site-level scripts from a host with the Configuration Manager console module installed.
- Most report scripts are read-only.
- Remediation scripts support safety features such as `-WhatIf` where applicable.

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
