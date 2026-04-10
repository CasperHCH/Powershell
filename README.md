
# PowerShell Enterprise Automation Library

Enterprise-oriented PowerShell scripts for administration, endpoint management, certificate operations, Atlassian automation, reporting, and secure service integrations.

## Repository Focus

This repository is organized around reusable PowerShell automation for:

- Active Directory and Exchange administration
- Infrastructure provisioning and baseline validation
- SCCM and endpoint-management operations
- Jira, Confluence, and other Atlassian workflows
- Certificate request and response handling
- System administration, monitoring, and remediation
- Reporting and export utilities

Most scripts are written as standalone tools with parameter validation, safer logging patterns, and reduced reliance on hardcoded environment values.

## Current Layout

- `autoload/` - profile-style helper scripts that can be loaded into an interactive shell
- `core/` - shared authentication, reporting, and utility functions
- `data/` - configuration data and tracked templates
- `docs/` - API references, templates, and development guidance
- `scripts/` - primary script library grouped by platform or function
- `Tools/` - utility assets and supporting files
- `WindowsPowershell/` - profile/bootstrap scripts for Windows PowerShell environments
- `archive/` - older or retained historical content

## Notable Script Areas

### Certificates

The certificate area now includes companion PKI workflow scripts for offline request and response handling:

- `scripts/Certificates/Install-PKICertificateServer.ps1`
- `scripts/Certificates/Install-PKICertificateResponse.ps1`

### Infrastructure

The infrastructure area provides a new manifest-driven scaffold for day-0 and day-1 automation covering Active Directory, PKI, and SCCM bootstrap patterns.

- `scripts/infrastructure/README.md`
- `scripts/infrastructure/Invoke-InfrastructureBootstrap.ps1`
- `scripts/infrastructure/config/Environment.Baseline.template.psd1`

### SCCM

The SCCM folder contains reporting, validation, client-health, collection-analysis, supersedence, and cleanup tooling. Start with `scripts/SCCM/README.md` for the current index.

### EPM Automation

The EPM automation area contains Jira-focused reporting and endpoint-management scripts, including:

- portfolio health reporting
- resource capacity reporting
- risk and issue analysis
- automated status reporting
- CMDB versus SCCM reconciliation

See `scripts/epm-automation/README.md` and `scripts/epm-automation/endpoint-management/README.md`.

## Usage Guidance

1. Clone the repository.
2. Open the script area relevant to the platform you are working on.
3. Read the local README in that folder when one exists.
4. Run scripts with explicit parameters instead of editing values inline.
5. Prefer `-WhatIf` or equivalent dry-run behavior where destructive operations are involved.

## Security and Documentation

- Use `Get-Credential`, `SecureString`, or approved secure storage for secrets.
- Avoid hardcoded domains, hosts, usernames, API keys, and file paths.
- Keep audit logs next to the script when the script performs sensitive or state-changing work.
- Follow `docs/guides/DEVELOPMENT_STANDARDS.md` for the current repository standards.

For SCCM software collection consolidation, keep environment-specific mappings in `data/SCCMSoftwareCollectionConsolidation.CanonicalMap.psd1` and use `data/SCCMSoftwareCollectionConsolidation.CanonicalMap.template.psd1` as the tracked baseline template.

## Additional References

- `CHANGELOG.md` for notable repository changes
- `docs/api-references/ATLASSIAN_API_REFERENCE.md` for Atlassian API notes
- `docs/guides/INFRASTRUCTURE_AUTOMATION_ROADMAP.md` for the phased infrastructure automation plan
- `.github/Copilot-Instructions.md` for repository-specific coding constraints

For details, use the documentation closest to the scripts you are changing or running.
