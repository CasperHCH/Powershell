# Secure PowerShell Library Quick Start Guide

This guide is a practical starting point for working in this repository without assuming an idealized project structure that does not exist in the current tree.

## Security Notice

This repository expects:

- no hardcoded credentials, API keys, or environment-specific secrets
- validated parameters instead of edited-in-place script constants
- audit-friendly logging for sensitive or state-changing operations

## Getting Started

### Prerequisites

- PowerShell 5.1 or PowerShell 7+
- Git
- rights appropriate to the platforms you are automating
- understanding of secure credential handling

### Initial Setup

1. Clone the repository.

```powershell
git clone https://github.com/CasperHCH/Powershell.git C:\PS
Set-Location C:\PS
```

2. Set execution policy if needed.

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

3. Review the script area you plan to use before running anything.

## Repository Navigation

### Core Areas

- `core/` - shared authentication, utility, and reporting helpers
- `scripts/` - main automation library grouped by domain or platform
- `docs/` - guides, templates, and API references
- `autoload/` - helper scripts intended for profile-style loading
- `data/` - tracked templates and configuration data

### Common Script Areas

- `scripts/active-directory/`
- `scripts/exchange/`
- `scripts/atlassian/`
- `scripts/SCCM/`
- `scripts/epm-automation/`
- `scripts/system-administration/`
- `scripts/Certificates/`

## Typical Workflow

1. Find the relevant script folder.
2. Read the nearest README or guide if one exists.
3. Review the script help block with `Get-Help`.
4. Prefer `-WhatIf`, `-DryRun`, or validation-only modes first.
5. Run with explicit parameters rather than editing the script body.

## Example Tasks

### Active Directory

```powershell
.\scripts\active-directory\Get-LockedOutLocation.ps1
```

### SCCM

```powershell
Get-Content .\scripts\SCCM\README.md
```

### EPM Automation

```powershell
Get-Content .\scripts\epm-automation\README.md
```

### Certificates

```powershell
Get-Help .\scripts\Certificates\Install-PKICertificateServer.ps1 -Full
Get-Help .\scripts\Certificates\Install-PKICertificateResponse.ps1 -Full
```

## Credential Handling

Never store live credentials in script files.

```powershell
$credential = Get-Credential
$credential | Export-Clixml -Path "$env:USERPROFILE\.credentials\example.xml"

$credential = Import-Clixml -Path "$env:USERPROFILE\.credentials\example.xml"
```

For API tokens, prefer a secure prompt or approved secret store.

## Creating or Updating Scripts

Use `docs/templates/Template.ps1` as the baseline when creating a new script.

Keep these rules in mind:

- use `Verb-Noun.ps1` naming
- place scripts in the closest matching domain folder
- include comment-based help
- add parameter validation
- use secure logging and avoid leaking sensitive values

## Validation Guidance

- Use `-WhatIf` when available.
- Use validation-only modes when the script supports them.
- If there is no active repository test structure for the script family, document the manual validation you performed.

## Additional Resources

- `README.md`
- `CHANGELOG.md`
- `.github/Copilot-Instructions.md`
- `docs/guides/DEVELOPMENT_STANDARDS.md`
- `docs/api-references/ATLASSIAN_API_REFERENCE.md`

For platform-specific work, prefer the documentation closest to the actual scripts you are running.