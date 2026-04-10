# Jira User Anonymization Troubleshooting Notes

This note documents anonymization edge cases seen when using `Manage-JiraUserLifecycle.ps1` against Jira on-prem environments.

## Main Finding

Display-name conventions are not a reliable way to decide whether a user is internal or externally sourced.

Use `directoryId` as the primary source of truth.

## Important Rule

Only treat a user as externally sourced when the Jira user record indicates a non-internal `directoryId`.

Do not infer directory source from values such as:

- `/External` suffixes in display names
- email naming patterns
- username conventions

## Failure Pattern

An anonymization request may appear to succeed when:

- the API returns a successful response
- Jira background task progress reaches completion
- the script logs success

but the user record still appears unchanged afterward.

This can happen for more than one reason:

1. The user is sourced from an external directory and Jira does not fully anonymize that user through the API path being used.
2. The Jira anonymization service completes the task request but the background operation does not apply the expected data changes.
3. The user still has active sessions, locks, or content dependencies that interfere with completion.

## Recommended Detection Logic

Use logic like this in eligibility checks:

```powershell
if ($User.directoryId -and $User.directoryId -ne '1') {
    return @{
        Eligible = $false
        Reason   = "External directory user (Directory ID: $($User.directoryId))"
        Action   = 'Remove from external directory and sync before anonymizing'
    }
}
```

## Recommended Verification Step

After Jira reports anonymization success, re-query the user and confirm the expected anonymized values are actually present.

Example verification pattern:

```powershell
$verifyUri = "$BaseUrl/rest/api/2/user?$identifierType=$([System.Web.HttpUtility]::UrlEncode($userIdentifier))"
$verifyUser = Invoke-RestMethod -Uri $verifyUri -Method Get -Headers $Headers -UseBasicParsing

if ($verifyUser.name -match '^jirauser\d+$') {
    Write-Log 'Verification success: user anonymized successfully' 'INFO'
} else {
    Write-Log 'Verification failed: user data not anonymized despite reported success' 'WARNING'
}
```

## Operational Guidance

### If the user is externally sourced

1. Remove or disable the user in the external directory.
2. Synchronize Jira user directories.
3. Confirm the Jira record now reflects the expected internal state or is otherwise eligible for anonymization.
4. Re-run the anonymization workflow.

### If the user is internal but anonymization still does not apply

1. Review Jira logs for anonymization-task failures.
2. Clear user sessions if appropriate.
3. Check for content or workflow locks.
4. Try manual anonymization through the Jira administration interface.
5. Escalate to platform support if the API reports success but repeated verification fails.

## Why This Note Exists

This file exists to capture the distinction between:

- apparent success reported by the Jira API or task system
- actual anonymization confirmed by a follow-up read of the user object

That distinction is important in `Manage-JiraUserLifecycle.ps1`, where the safe behavior is to verify outcomes rather than trust the first success signal.

## Related Files

- `Manage-JiraUserLifecycle.ps1`
- `Test-AnonymizationPayload.ps1`
- `Test-AnonymizationTaskID.ps1`
- `Test-UserResolution.ps1`