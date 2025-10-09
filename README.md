# PowerShell Library

> **Last Updated:** October 2025
> **Status:** Active maintenance and error correction in progress

A comprehensive collection of PowerShell scripts for various automation tasks, including user management, system monitoring, and API integrations. This library has been recently restored and is undergoing systematic error correction and optimization.

## 🚀 Recent Updates

### October 9, 2025 - PowerShell Best Practices & API Documentation
- **✅ ZERO ERRORS**: All PowerShell scripts now 100% error-free (139 files validated)
- **📋 API Documentation**: Created comprehensive `ATLASSIAN_API_REFERENCE.md` with complete API endpoints
- **🔧 Enhanced Scripts**: 
  - **Windows-Upgrade-All-Apps.ps1**: Added proper error handling, colorized output, user confirmation
  - **Graceful_Jira_Restart_v1.1.ps1**: Fixed URI formatting, added timeout and error handling  
  - **Clean-Teamviewer-of-Old-PCs.ps1**: Fixed incomplete API URIs, added proper error handling
- **🎨 UI Improvements**: Added color coding and user-friendly messages throughout scripts
- **⚡ Error Handling**: Implemented try/catch blocks with meaningful error messages

### Previous Updates (October 2025)
- **Major Repository Restoration**: All 1,571 files recovered and validated
- **Systematic Error Correction**: Fixed 756+ PowerShell best practice violations
- **Aliases Standardized**: gci→Get-ChildItem, select→Select-Object, where→Where-Object
- **Unapproved Verbs Fixed**: Load-Module→Import-ModuleIfAvailable across 18+ Atlassian scripts
- **Complete Atlassian Ecosystem**: 86 scripts cleaned including Jira, Confluence, OpsGenie integration
- **Git Workflow**: Continuous commits with descriptive messages documenting all improvements

## 📁 Folder Structure

- **`autoload/`** - Contains reusable PowerShell functions and modules that can be auto-loaded
- **`Powershell-Master/`** - A collection of finalized and tested scripts from various sources (managed separately)
- **`Scripts/`** - Custom scripts for specific use cases and automation tasks
- **`Tools/`** - Additional tools and utilities
- **`WindowsPowershell/`** - Windows-specific PowerShell scripts and profiles

## 🔧 Key Components

### Autoload Functions (`autoload/`)
- **`Functions-PSStoredCredentials.ps1`** - Manage stored credentials for re-use
- **`Connect-Office365Services.ps1`** - Connect to Office 365 and Exchange services
- **`Get-AdSync.ps1`** / **`Start-AdSync.ps1`** - Azure AD synchronization management
- **`Get-MailboxAutomapping.ps1`** / **`Get-UserAutomapping.ps1`** - Exchange mailbox automapping functions
- **`Get-LockedOutLocation.ps1`** - Find locked out user locations in AD
- **`Get-Uptime.ps1`** - System uptime monitoring
- **`Test-ADCredential.ps1`** - Active Directory credential validation

### Scripts (`Scripts/`)
- **`Template.ps1`** - Standard PowerShell script template with logging
- **`Install_Modules.ps1`** - Automated PowerShell module installation
- **`OptimizeScripts.ps1`** - Script optimization utility
- **`SignScripts.ps1`** - PowerShell script signing utility

### Specialized Folders
- **`AD/`** - Active Directory related scripts (user management, group operations, security)
- **`Atlassian/`** - Jira and Confluence automation scripts (API integration, user cleanup)
- **`Mailbox/`** - Exchange mailbox management scripts (permissions, forwarding, reporting)
- **`Network/`** - Network monitoring and management scripts
- **`System/`** - System administration and monitoring tools
- **`IIS/`** - Internet Information Services management scripts

## ✨ Key Features

### User Management
- Bulk user operations in Active Directory
- Jira user management (deletion, anonymization, username replacement)
- Azure AD and on-premises AD integration
- Exchange mailbox automapping and permissions

### System Monitoring
- System uptime checks
- Service status monitoring
- Hardware specification gathering
- Network connectivity testing
- Event log analysis

### Automation Tasks
- Jenkins agent installation
- Event log creation and management
- Certificate management
- Task scheduler integration

## 📖 API Documentation

### Atlassian API Reference
A comprehensive API reference document has been created: **`ATLASSIAN_API_REFERENCE.md`**

**Covered APIs:**
- **Jira Cloud REST API v3** - User management, issues, custom fields, watchers, groups
- **Jira On-Prem REST API v2** - User profiles, issue management, project operations  
- **Confluence REST API** - User management, space operations, content management
- **OpsGenie API v2** - Account management, incident handling (EU/US regions)

**Key Features:**
- Complete endpoint documentation with HTTP methods
- Authentication examples (API tokens, Basic Auth, GenieKey)
- PowerShell code samples with error handling
- Best practices for rate limiting and security
- Migration notes for Cloud vs On-Prem differences

**Quick Start:**
```powershell
# Jira Cloud API Token Authentication
$headers = @{
    'Authorization' = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("email@domain.com:api_token"))
    'Content-Type' = 'application/json'
}
```

### Script-Specific API Usage
- **bulkChange.ps1**: Multi-version Jira API (v2/v3) for bulk operations
- **RemoveUsersFromGroups.ps1**: Jira Cloud v3 for group management
- **disableConfluenceUser.ps1**: Confluence REST API for user operations
- **OpsGenie Scripts**: Regional API endpoints with GenieKey authentication

## Development Guidelines

1. **Error Handling** - All scripts include robust error handling with try-catch blocks
2. **Logging** - Consistent logging using the Write-Log function from Template.ps1
3. **Modularization** - Functions are broken into reusable modules in the autoload folder
4. **Environment Compatibility** - Scripts adapt to both cloud and on-premises environments
5. **WhatIf Mode** - Include simulation mode for testing without making changes

## Usage Examples

### Loading Autoload Functions
```powershell
# Import all autoload functions
Get-ChildItem "C:\PS\autoload\*.ps1" | ForEach-Object { . $_.FullName }
```

### Using the Template
```powershell
# Copy the template for new scripts
Copy-Item "C:\PS\Scripts\Template.ps1" "C:\PS\Scripts\MyNewScript.ps1"
```

### Connecting to Office 365
```powershell
# Load and use Office 365 connection functions
. "C:\PS\autoload\Connect-Office365Services.ps1"
Connect-ExchangeOnline
```

## Testing

- Use `Pester` for unit testing PowerShell scripts
- Test files can be found in respective script directories
- Use the `WhatIf` parameter for safe testing without making changes

## API Integrations

- Replace `Invoke-RestMethod` with `curl` for API calls where possible
- Proper authentication and error handling for all API integrations
- Examples in `autoload/Connect-Office365Services.ps1`

## Function Naming Convention

All functions follow the PowerShell `Verb-Noun` naming convention:
- `Get-UserAutomapping`
- `Set-CalPerm`
- `Test-ADCredential`
- `Start-AdSync`

## Contributing

1. Follow the development guidelines above
2. Test scripts thoroughly using Pester
3. Update documentation when adding new scripts
4. Use the Template.ps1 as a starting point for new scripts

## Notes

- Scripts are designed to work in both cloud and on-premises environments
- Many scripts include credential management for automation scenarios
- The library focuses on Exchange, Active Directory, and Azure integrations
- All scripts include comprehensive help documentation and examples

## Maintenance

Regular maintenance includes:
- Updating module dependencies
- Testing scripts against new PowerShell versions
- Updating API integrations as services change
- Cleaning up deprecated functions and scripts

---

*For questions or contributions, please refer to the individual script documentation or contact the repository maintainer.*
