# Atlassian API Reference Documentation

> **Last Updated:** October 2025  
> **Status:** Enhanced with JIRA On-Premise user management and anonymization APIs

## Overview
This document provides comprehensive API references for Atlassian scripts in the PowerShell collection, including Jira Cloud, Jira On-Prem with enterprise user management, Confluence, and OpsGenie integrations.

## Authentication

### Jira Cloud API Token
- **URL to create tokens**: https://id.atlassian.com/manage-profile/security/api-tokens
- **Authentication method**: Basic Auth (email:token)
- **Format**: `Authorization: Basic <base64(email:token)>`

### Jira On-Prem
- **Authentication methods**: Basic Auth, Personal Access Tokens
- **Format**: `Authorization: Basic <base64(username:password)>`

### OpsGenie API
- **EU API Base**: https://api.eu.opsgenie.com/v2/
- **US API Base**: https://api.opsgenie.com/v2/
- **Authentication**: `Authorization: GenieKey <api-key>`

## API Endpoints

### Jira Cloud REST API v3

#### User Management
- **Search Users**: `GET /rest/api/3/user/search?query={query}`
- **Get User**: `GET /rest/api/3/user?accountId={accountId}`
- **Update User**: `PUT /rest/api/3/user?accountId={accountId}`

#### Issue Management
- **Search Issues**: `GET /rest/api/3/search?jql={jql}`
- **Get Issue**: `GET /rest/api/3/issue/{issueIdOrKey}`
- **Update Issue**: `PUT /rest/api/3/issue/{issueIdOrKey}`
- **Assign Issue**: `PUT /rest/api/2/issue/{issueIdOrKey}/assignee`

#### Watchers
- **Add Watcher**: `POST /rest/api/2/issue/{issueIdOrKey}/watchers`
- **Remove Watcher**: `DELETE /rest/api/2/issue/{issueIdOrKey}/watchers?username={username}`
- **Get Watchers**: `GET /rest/api/2/issue/{issueIdOrKey}/watchers`

#### Groups
- **Add User to Group**: `POST /rest/api/3/group/user?groupId={groupId}&accountId={accountId}`
- **Remove User from Group**: `DELETE /rest/api/3/group/user?groupId={groupId}&accountId={accountId}`
- **Get Group Members**: `GET /rest/api/3/group/member?groupId={groupId}`

#### Custom Fields
- **Get Custom Fields**: `GET /rest/api/2/customFields`
- **Delete Custom Field**: `DELETE /rest/api/3/field/{fieldId}`
- **Search Custom Fields**: `GET /rest/api/3/field/search?startAt={startAt}`
- **Get Field Contexts**: `GET /rest/api/2/field/{fieldId}/context`
- **Add Custom Field Options**: `POST /rest/api/3/field/{fieldId}/context/{contextId}/option`

### Jira On-Prem REST API v2

#### User Management & Enterprise Operations
- **Get User**: `GET /rest/api/2/user?username={username}`
- **Update User**: `PUT /rest/api/2/user?username={username}`
- **Search Users**: `GET /rest/api/2/user/search?username={username}`
- **Search with Query**: `GET /rest/api/2/user/search?username=.&query={query}`
- **Include Inactive**: `GET /rest/api/2/user/search?username=.&query={query}&includeInactive=true`
- **User Picker**: `GET /rest/api/2/user/picker?query={query}`
- **Disable User**: `PUT /rest/api/2/user?username={username}` with `{"active": false}`
- **Anonymize User**: `POST /rest/api/2/user/anonymization` with `{"userKey": "{userKey}", "newOwnerKey": "{ownerKey}"}`

#### Project Management
- **Get Projects**: `GET /rest/api/2/project`
- **Get Project Lead**: `GET /rest/api/2/project/{projectKey}`
- **Update Project Lead**: `PUT /rest/api/2/project/{projectKey}` with `{"lead": "{username}"}`
- **Check Project Permissions**: `GET /rest/api/2/mypermissions?projectKey={projectKey}`

#### Issue Management
- **Search Issues**: `GET /rest/api/2/search?jql={jql}`
- **Get Issue**: `GET /rest/api/2/issue/{issueIdOrKey}`
- **Update Issue**: `PUT /rest/api/2/issue/{issueIdOrKey}`

### Confluence REST API

#### User Management
- **Get User**: `GET /rest/api/user?username={username}`
- **Update User**: `PUT /rest/api/user?username={username}`
- **Disable User**: `PUT /rest/api/user?username={username}` with `{"active": false}`

### OpsGenie API v2

#### Account Information
- **Get Account Info**: `GET /v2/account`
- **Authentication Header**: `Authorization: GenieKey {api-key}`

## Script-Specific API Usage

### bulkChange.ps1
- **Primary APIs**: Jira Cloud REST API v3, v2 (mixed)
- **Key Operations**: Issue search, assignee updates, watcher management
- **Authentication**: Basic Auth with API token

### RemoveUsersFromGroups.ps1
- **Primary API**: Jira Cloud REST API v3
- **Key Operations**: User search, group member removal
- **Authentication**: Basic Auth with API token

### AddOptionsToCustomField.ps1
- **Primary API**: Jira Cloud REST API v2/v3
- **Key Operations**: Custom field management, context handling
- **Documentation Reference**: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-custom-field-options/

### disableConfluenceUser.ps1
- **Primary API**: Confluence REST API
- **Key Operations**: User status updates
- **Authentication**: Basic Auth

### RenameUsernamesFromNewADUPN.ps1
- **Primary API**: Jira On-Prem REST API v2
- **Key Operations**: User profile updates, username changes
- **Authentication**: Basic Auth

### OpsGenie Scripts
- **Primary API**: OpsGenie API v2
- **Regions**: EU (api.eu.opsgenie.com) and US (api.opsgenie.com)
- **Authentication**: GenieKey header

## Best Practices

### Error Handling
```powershell
try {
    $response = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -ErrorAction Stop
} catch {
    Write-Error "API request failed: $($_.Exception.Message)"
    throw
}
```

### Rate Limiting
- Implement retry logic with exponential backoff
- Monitor response headers for rate limit information
- Use pagination for large result sets

### Security
- Store API tokens securely (avoid hardcoding)
- Use HTTPS for all API calls
- Validate SSL certificates
- Implement proper authentication headers

### Logging
```powershell
Write-Log -Level INFO -Message "Making API call to: $uri"
Write-Log -Level DEBUG -Message "Request headers: $($headers | ConvertTo-Json)"
```

## Common Issues and Solutions

### Authentication Failures
- Verify API token validity and permissions
- Check base64 encoding for basic auth
- Ensure correct API endpoint URLs

### Rate Limiting
- Implement exponential backoff
- Use bulk operations where available
- Cache responses when appropriate

### SSL/TLS Issues
```powershell
# Add if encountering SSL issues (use with caution)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
```

## Migration Notes

### Cloud vs On-Prem Differences
- API versioning: Cloud uses v3, On-Prem often uses v2
- User identifiers: Cloud uses accountId, On-Prem uses username
- Authentication: Cloud requires API tokens, On-Prem supports various methods
- Base URLs: Cloud uses `{instance}.atlassian.net`, On-Prem uses custom domains

---
*Last Updated: October 9, 2025*
*For the latest API documentation, refer to official Atlassian developer documentation*