# Anonymization Progress Monitoring Fix

## Issue Identified

The anonymization process was submitting successfully but **not actually completing** because the progress monitoring was incorrect.

### Problem Analysis

**Logs showed false success:**
```
[SUCCESS] Anonymization request submitted successfully
[SUCCESS] Anonymization progress check complete (no active process detected)
[SUCCESS] Successfully anonymized user: Pandey, Pankaj Kumar /External [sce9995]
```

**But user remained unanonymized in JIRA interface:**
- Full name: "Pandey, Pankaj Kumar /External" (should be anonymized)
- Email: "pankaj-kumar.pandey@teliacompany.com" (should be anonymized)

### Root Cause

**Wrong API endpoint usage:**
- ❌ **Script was calling**: `/rest/api/2/user/anonymization/progress` (generic endpoint)
- ✅ **Should be calling**: `/rest/api/2/user/anonymization/progress?taskId=401382` (task-specific)

**Response provided the correct endpoint:**
```json
{
  "progressUrl": "/rest/api/2/user/anonymization/progress?taskId=401382",
  "status": "IN_PROGRESS"
}
```

## Solution Implemented

### 1. Extract Task ID from Response
```powershell
$taskId = if ($result.progressUrl -match "taskId=(\d+)") { $matches[1] } else { $null }
```

### 2. Use Task-Specific Monitoring
```powershell
if ($TaskId) {
    $progressUri = "$BaseUrl/rest/api/2/user/anonymization/progress?taskId=$TaskId"
} else {
    $progressUri = "$BaseUrl/rest/api/2/user/anonymization/progress"
}
```

### 3. Handle Task-Specific Status Values
```powershell
if ($status -eq "FINISHED" -or $status -eq "COMPLETED") {
    return $true  # Actually completed
} elseif ($status -eq "FAILED" -or $status -eq "ERROR") {
    return $false # Failed
} elseif ($status -eq "IN_PROGRESS" -or $status -eq "RUNNING") {
    # Continue monitoring
}
```

## Expected Behavior After Fix

### Before Fix (False Success)
1. ✅ Submit anonymization request
2. ❌ Check generic progress endpoint (always empty)
3. ❌ Return "success" immediately
4. ❌ User remains unanonymized

### After Fix (True Success)
1. ✅ Submit anonymization request
2. ✅ Extract task ID: `401382`
3. ✅ Monitor specific task: `/progress?taskId=401382`
4. ✅ Wait for actual `FINISHED` status
5. ✅ User properly anonymized in JIRA

## Verification

When the fix is deployed, the logs should show:
```
[INFO] Progress monitoring URL: /rest/api/2/user/anonymization/progress?taskId=401382
[INFO] Task 401382 status: IN_PROGRESS - Progress: 0% for user: sce9995
[INFO] Task 401382 status: IN_PROGRESS - Progress: 50% for user: sce9995
[SUCCESS] Anonymization task completed successfully: FINISHED
```

And the user should appear anonymized in JIRA interface:
- Full name: "user-xxxxx" (anonymized)
- Email: "user-xxxxx@anonymous.invalid" (anonymized)

## Impact

This fix ensures **actual GDPR compliance** instead of just logging false success messages. The anonymization process will now properly complete and verify before reporting success.