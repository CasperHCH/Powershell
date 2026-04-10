# Infrastructure Automation

This folder scaffolds manifest-driven infrastructure automation for platform build and validation workflows that complement the repository's existing day-2 operational scripts.

## Design Goals

- Separate environment data from code by using a PSD1 manifest.
- Keep build steps domain-specific and reusable.
- Provide safe orchestration with WhatIf support.
- Emphasize preflight checks and post-build validation.
- Keep logs and audit artifacts next to the executing script.

## Layout

- Infrastructure-Common.ps1: shared helper functions for logging, manifest loading, and preflight checks
- Invoke-InfrastructureBootstrap.ps1: top-level orchestrator for phased execution
- config/Environment.Baseline.template.psd1: example environment manifest template
- config/Environment.lab.psd1: fuller lab example spanning AD, PKI, and SCCM
- config/Environment.SCCM.template.ps1: SCCM-focused variable-driven manifest template
- active-directory/: Active Directory baseline and validation scaffolds
- pki/: PKI and AD CS baseline and validation scaffolds
- sccm/: SCCM prerequisite and health scaffolds

## Suggested Usage Pattern

1. Copy config/Environment.Baseline.template.psd1 to an environment-specific PSD1 file, start from config/Environment.lab.psd1 for a fuller lab example, or use config/Environment.SCCM.template.ps1 for variable-driven SCCM-only editing.
2. Populate organization, server, naming, and role values for the target environment.
3. Run Invoke-InfrastructureBootstrap.ps1 with -ValidateOnly first.
4. Execute one platform phase at a time with -WhatIf before any live run.
5. Archive resulting logs with the related change record.

## Current State

The scripts in this folder are intentionally scaffold-first. They establish the manifest and orchestration pattern, implement common validation behavior, and provide safe entry points for future build automation.

The first non-placeholder implementations are `active-directory/Test-ADDomainHealth.ps1`, `active-directory/Install-FirstDomainController.ps1`, `active-directory/New-ADBaselineOUs.ps1`, `active-directory/New-ADBaselineGroups.ps1`, and `active-directory/New-ADBaselineGpos.ps1`. The validator now performs real checks for domain lookup, forest lookup, configured-versus-discovered domain controllers, DNS records, FSMO exposure, ICMP reachability, SYSVOL access, replication-service signals, time-service reachability, and optional `dcdiag` and `repadmin` checks. The Active Directory build side now supports validate-only preflight, optional prerequisite feature installation, manifest-driven forest promotion, and baseline OU, group, and GPO creation.

The SCCM validator now uses richer manifest data to check SQL server definition and reachability, management-point and software-update-point settings, distribution-point entries, standard collection definitions, source-path formatting, boundary definitions, and boundary-group site-system relationships.

The SCCM build side now includes `sccm/New-SccmBoundaryModel.ps1` for boundary and boundary-group creation plus `sccm/New-SccmBaselineCollections.ps1`, which uses `SCCM.StandardCollections` from the manifest to validate or create baseline device collections once the Configuration Manager console cmdlets are available.

## Planned Expansion

See docs/guides/INFRASTRUCTURE_AUTOMATION_ROADMAP.md for the recommended delivery order and effort profile.

## SCCM To-Do

- Add `sccm/New-SccmBoundaryModel.ps1` to create boundaries and boundary groups from the manifest.
- Extend `sccm/New-SccmBaselineCollections.ps1` with collection membership-rule support for managed and pilot collection population.
- Extend `sccm/Test-SccmSiteHealth.ps1` with optional live Configuration Manager provider checks when the console module is available.
- Add a dedicated SCCM environment manifest with easy-to-edit variables for server names, site code, source paths, and IP/subnet values.