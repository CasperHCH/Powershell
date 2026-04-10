# ChangeFilterOwner.ps1 - Quick Reference

Quick operational reference for `ChangeFilterOwner.ps1`.

## Current Script Purpose

The script scans `.log` files for messages like `Filter {ID} has no owner`, extracts the filter IDs, and attempts to assign a new owner through the Jira REST API.

It supports:

- secure password prompting
- validation-only checks
- optional user validation skip for restricted Jira environments
- `-WhatIf` preview support through `SupportsShouldProcess`
- per-run audit logging to `FilterOwnerChange_[SessionId].log`

## Usage

### Basic Usage

```powershell
.\ChangeFilterOwner.ps1 `
    -LogFolder "C:\Logs\JiraFilters" `
    -JiraUrl "https://jira.example.org" `
    -JiraUser "jira-admin" `
    -NewOwner "service-owner"
```

### Skip User Validation

Use this when the account can update filter ownership but cannot query the Jira user endpoint.

```powershell
.\ChangeFilterOwner.ps1 `
    -LogFolder "C:\Logs\JiraFilters" `
    -JiraUrl "https://jira.example.org" `
    -JiraUser "jira-admin" `
    -NewOwner "service-owner" `
    -SkipUserValidation
```

### Validate Without Updating

```powershell
.\ChangeFilterOwner.ps1 `
    -LogFolder "C:\Logs\JiraFilters" `
    -JiraUrl "https://jira.example.org" `
    -JiraUser "jira-admin" `
    -NewOwner "service-owner" `
    -ValidateOnly
```

### Supply Password as SecureString

```powershell
$securePassword = Read-Host "Enter password" -AsSecureString

.\ChangeFilterOwner.ps1 `
    -LogFolder "C:\Logs\JiraFilters" `
    -JiraUrl "https://jira.example.org" `
    -JiraUser "jira-admin" `
    -JiraPassword $securePassword `
    -NewOwner "service-owner"
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-LogFolder` | Yes | Folder containing `.log` files with missing-owner entries |
| `-JiraUrl` | Yes | Jira base URL, for example `https://jira.example.org` |
| `-JiraUser` | Yes | Jira account used for authentication |
| `-JiraPassword` | No | `SecureString` password; prompts if omitted |
| `-NewOwner` | Yes | Username of the target filter owner |
| `-ValidateOnly` | No | Run checks without changing ownership |
| `-SkipUserValidation` | No | Skip Jira user lookup before processing |

## Common Failure Modes

### 403 on User Validation

Cause: the authenticated account can access filters but cannot call the Jira user lookup API.

Use:

```powershell
-SkipUserValidation
```

### 403 on Filter Update

Common causes:

1. The account lacks filter-administration rights.
2. The filter is private or otherwise inaccessible.
3. The target owner cannot be assigned in the current Jira permission model.

### 401 Unauthorized

Cause: authentication failed. Re-check the Jira username, password, and base URL.

## Output and Logging

The script writes:

- real-time progress to the console
- detailed execution and audit events to a log file next to the script
- a per-run log in the format `FilterOwnerChange_[SessionId].log`

Example:

```text
FilterOwnerChange_a67791d6.log
```

## Recommended Workflow

1. Start with `-ValidateOnly`.
2. If user validation fails due to Jira restrictions, rerun with `-SkipUserValidation`.
3. Review the generated log for per-filter failures.
4. Re-run against a smaller log subset if troubleshooting is needed.

## Related Files

- `ChangeFilterOwner.ps1`
- `Manage-JiraUserLifecycle.ps1`
- `EXTERNAL_USER_ANONYMIZATION_FIX.md`
