# JIRA Enterprise User Management Documentation

> **Last Updated:** October 10, 2025
> **Script Version:** 3.0
> **Script Name:** Manage-JiraUserLifecycle.ps1
> **Author:** Enterprise PowerShell Team

## Overview

The `Manage-JiraUserLifecycle.ps1` script provides comprehensive enterprise-grade user lifecycle management for JIRA on-premise instances. It handles the complete user lifecycle: discovery, project lead conflict resolution, user disabling, and GDPR-compliant anonymization with proper content ownership transfer.

## Key Features

### 🔍 Advanced User Discovery
- **Multi-method search**: Tries 10+ different API endpoints to find users
- **Inactive user detection**: Comprehensive search for already disabled users
- **Domain-based filtering**: Email domain and username pattern matching
- **CSV import support**: Bulk operations from structured data

### ⚖️ Project Lead Conflict Resolution
- **Automatic detection**: Identifies project leadership conflicts before disable
- **Configurable transfer**: Specify new project lead with `-NewProjectLead`
- **Multiple payload formats**: Enhanced compatibility with different JIRA versions
- **Conflict reporting**: Detailed logging of project transfers

### 🛡️ GDPR-Compliant Anonymization
- **Content ownership transfer**: Proper `newOwnerKey` parameter handling
- **Eligibility checking**: Validates users can be anonymized before attempting
- **Progress monitoring**: Real-time tracking of anonymization process
- **Audit trail**: Comprehensive logging for compliance requirements

### 📊 Enterprise Reporting
- **Outcome categorization**: Successful, failed, and manual intervention tracking
- **CSV exports**: Detailed reports for audit and compliance
- **Debug logging**: Optional verbose output with `-EnableDebugLogging`
- **Status tracking**: Clear indication of active vs inactive user processing

## Usage Examples

### Basic User Discovery and Anonymization
```powershell
.\Manage-JiraUserLifecycle.ps1 -EmailDomains "teliacompany.com" -JiraBaseUrl "https://jira-ks.norlys.dk" -AnonymizeUsers -PersonalAccessToken "your_token"
```

### With Project Lead Transfer and Debug Logging
```powershell
.\Manage-JiraUserLifecycle.ps1 -EmailDomains "teliacompany.com" -JiraBaseUrl "https://jira-ks.norlys.dk" -AnonymizeUsers -ForceProjectLeadTransfer -NewProjectLead "admin" -PersonalAccessToken "your_token" -EnableDebugLogging
```

### Dry Run Mode for Testing
```powershell
.\Manage-JiraUserLifecycle.ps1 -EmailDomains "teliacompany.com" -JiraBaseUrl "https://jira-ks.norlys.dk" -AnonymizeUsers -DryRun -PersonalAccessToken "your_token"
```

## API Endpoints Used

### User Discovery
1. `GET /rest/api/2/user/search?username=@{domain}` - Direct domain search
2. `GET /rest/api/2/user/search?username=.&query=@{domain}` - Query-based search
3. `GET /rest/api/2/user/picker?query=@{domain}` - User picker API
4. `GET /rest/api/2/user/search?username=.&query=*&includeInactive=true` - Comprehensive fallback

### Project Management
1. `GET /rest/api/2/project` - List all projects
2. `GET /rest/api/2/project/{key}` - Get project details
3. `PUT /rest/api/2/project/{key}` - Update project lead

### User Operations
1. `PUT /rest/api/2/user?username={username}` - Disable user
2. `GET /rest/api/2/user/anonymization/{userKey}/eligibility` - Check anonymization eligibility
3. `POST /rest/api/2/user/anonymization` - Anonymize user with content transfer

## Output Files

### Log Files
- **Main log**: `JiraBulkUserDisable_YYYYMMDD_HHMMSS.log`
- **Debug output**: Enabled with `-EnableDebugLogging` parameter

### CSV Reports (when applicable)
- **Successful operations**: Users processed successfully
- **Failed operations**: Users that encountered errors
- **Manual intervention**: Users requiring administrator attention

## Security & Compliance

### Authentication Methods
- **Personal Access Tokens** (recommended)
- **Basic Authentication** with username/password
- **Encrypted credential files** for secure automation

### GDPR Compliance
- **Content ownership transfer**: All user content properly reassigned
- **Audit trails**: Complete logging of all operations
- **Anonymization validation**: Eligibility checking before processing
- **Right to be forgotten**: Proper personal data removal

### Enterprise Security Features
- **Input sanitization**: Protection against injection attacks
- **Secure logging**: Tamper-resistant audit trails
- **SSL/TLS validation**: Secure API communications
- **Role-based permissions**: JIRA admin rights validation

## Troubleshooting

### User Discovery Issues
- **Enable debug logging**: Use `-EnableDebugLogging` for detailed output
- **Check permissions**: Ensure JIRA admin rights for user search
- **Verify domains**: Confirm email domains exist in the system
- **Test manually**: Verify users exist in JIRA web interface

### Anonymization Failures
- **Content ownership**: Ensure `newOwnerKey` user exists and has permissions
- **Project conflicts**: Use `-ForceProjectLeadTransfer` for automatic resolution
- **Eligibility issues**: Check anonymization eligibility requirements
- **Timeout handling**: Adjust `-AnonymizationTimeout` for large datasets

## Version History

### v3.0 (October 2025)
- Enhanced inactive user discovery with comprehensive fallback search
- GDPR-compliant anonymization with proper content ownership transfer
- Project lead conflict resolution with configurable transfer targets
- Optional debug logging with `-EnableDebugLogging` parameter
- Enhanced batch processing with manual intervention tracking

### v2.0 (Previous)
- Basic user disable and anonymization functionality
- CSV import and domain-based filtering
- Enterprise logging framework integration

### v1.0 (Initial)
- Simple user disable operations
- Basic authentication and logging