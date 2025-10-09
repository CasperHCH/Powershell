# PowerShell Library

> **Last Updated:** October 9, 2025
> **Status:** ✅ Fully reorganized with modern folder structure and comprehensive error correction

A comprehensive collection of PowerShell scripts for automation tasks including user management, system monitoring, and API integrations. This library has been completely reorganized following modern PowerShell best practices with a domain-organized structure.

## 🚀 Latest Updates

### October 9, 2025 - Major Repository Reorganization & Folder Structure Implementation
- **�️ COMPLETE RESTRUCTURE**: Implemented modern, domain-organized folder hierarchy
  - **Old Structure**: Flat `Scripts/` folder with mixed content
  - **New Structure**: Domain-organized with `core/`, `scripts/`, `docs/`, `tools/`, `data/`, `tests/`
- **📂 ORGANIZED CATEGORIES**: Scripts now properly categorized by function
  - **Exchange & Office 365** → `scripts/exchange/`
  - **Active Directory** → `scripts/active-directory/`
  - **System Administration** → `scripts/system-administration/`
  - **Atlassian Products** → `scripts/atlassian/`
  - **Network Operations** → `scripts/network/`
  - **Communication Tools** → `scripts/communication/`
- **🔧 ENHANCED PROFILE**: Updated PowerShell profile for new structure with colorized loading
- **📚 MODERNIZED DOCS**: Enhanced Copilot instructions with current best practices and security patterns

### Previous Milestones (October 2025)
- **✅ ZERO ERRORS**: All PowerShell scripts now 100% error-free (1400+ files validated)
- **� SECURITY HARDENING**: Replaced hardcoded credentials with secure management
- **� API DOCUMENTATION**: Comprehensive Atlassian API reference with PowerShell examples  
- **⚡ BEST PRACTICES**: Advanced error handling, parameter validation, colorized UIs
- **🎯 STANDARDIZATION**: Fixed 750+ PowerShell violations, standardized aliases and verbs

## 📁 Modern Folder Structure

### 🏗️ **Core Infrastructure**
- **`core/`** - Reusable modules and shared functions
  - `authentication/` - Credential management, AD authentication, Office 365 connections
  - `utilities/` - General utility functions, system monitoring, file operations
  - `reporting/` - System reporting, hardware specification gathering
- **`autoload/`** - Legacy auto-loading functions (maintained for compatibility)

### � **Domain-Organized Scripts**
- **`scripts/`** - Main script collection organized by functional domain
  - `exchange/` - Office 365, Exchange mailbox management, permissions, automapping
  - `active-directory/` - User lifecycle, group management, security, synchronization
  - `communication/` - Lync/Skype, Teams, email automation, remote access
  - `atlassian/` - Jira Cloud/On-Prem, Confluence, OpsGenie integration and automation
  - `system-administration/` - IIS management, monitoring, backup, maintenance, security
  - `network/` - Connectivity testing, infrastructure monitoring, port validation
  - `reporting/` - Excel integration, data export, system reporting
  - `integration/` - Database connections, external API integrations

### 🛠️ **Development & Operations**
- **`tools/`** - Development utilities and operational tools
  - `development/` - Script signing, optimization, testing utilities
  - `installation/` - Module installation scripts, environment setup
  - `legacy/` - Archived tools and historical configurations
- **`docs/`** - Comprehensive documentation
  - `api-references/` - Complete API documentation with PowerShell examples
  - `guides/` - Step-by-step procedures and best practice guides  
  - `templates/` - Standard script templates and code examples

### 📊 **Data & Testing**
- **`data/`** - Configuration files, logs, and reports
  - `config/` - Configuration files and settings
  - `logs/` - Execution logs and audit trails
  - `reports/` - Generated reports and analysis outputs
- **`tests/`** - Testing framework and validation
  - `unit-tests/` - Individual function and module tests
  - `integration-tests/` - End-to-end workflow testing
  - `validation-scripts/` - Script validation and compliance checking

## ✨ Key Features

### 👥 **User Management**
- **Active Directory**: Bulk user operations, group management, security policy enforcement
- **Atlassian Products**: Comprehensive Jira/Confluence user lifecycle management
- **Office 365/Exchange**: Mailbox provisioning, permissions, automapping, forwarding

### 🖥️ **System Administration**
- **Monitoring**: Real-time system health, uptime tracking, service status validation
- **Maintenance**: IIS log cleanup, certificate management, automated backup operations
- **Security**: Credential management, certificate operations, access control validation

### 🌐 **Network & Integration**
- **Connectivity Testing**: Multi-endpoint validation, port accessibility, SSL certificate verification
- **API Integration**: Atlassian REST APIs, Office 365 Graph API, OpsGenie incident management
- **Data Processing**: Excel integration, CSV reporting, database connectivity

### 🤖 **Automation & DevOps**
- **Deployment**: Jenkins agent installation, automated application updates
- **Workflow**: Task scheduler integration, event-driven automation
- **Development**: Script signing, optimization, validation frameworks

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

### Loading Core Modules
```powershell
# PowerShell profile automatically loads core modules
# Manual loading if needed:
Get-ChildItem "C:\PS\core\*.ps1" -Recurse | ForEach-Object { . $_.FullName }
```

### Using Script Templates
```powershell
# Copy the standard template for new scripts
Copy-Item "C:\PS\docs\templates\Template.ps1" "C:\PS\scripts\[category]\MyNewScript.ps1"
```

### Connecting to Office 365
```powershell
# Load and use Office 365 connection functions
. "C:\PS\core\authentication\Connect-Office365Services.ps1"
Connect-ExchangeOnline
```

### Running Organized Scripts
```powershell
# Exchange operations
. "C:\PS\scripts\exchange\Get-MailboxAutomapping.ps1"

# Active Directory management  
. "C:\PS\scripts\active-directory\Get-LockedOutLocation.ps1"

# System administration
. "C:\PS\scripts\system-administration\Get-Uptime.ps1"
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

## 🔧 Development Guidelines

### **Script Organization**
1. **Categorization**: Place scripts in appropriate domain folders (`scripts/exchange/`, `scripts/active-directory/`, etc.)
2. **Naming Convention**: Follow PowerShell `Verb-Noun` pattern (e.g., `Get-MailboxPermissions.ps1`)  
3. **Templates**: Use `docs/templates/Template.ps1` as starting point for new scripts
4. **Documentation**: Include comprehensive help blocks and examples

### **Code Quality Standards**
- **Error Handling**: Implement try/catch blocks with meaningful error messages
- **Parameter Validation**: Use `[Parameter()]` attributes with validation sets
- **Security**: Never hardcode credentials; use secure credential management
- **Testing**: Create corresponding test files in `tests/` directory
- **Logging**: Use consistent logging patterns from template

### **API Integration Best Practices**  
- **Authentication**: Use secure token/credential storage methods
- **Error Handling**: Implement proper API error response handling
- **Rate Limiting**: Respect API rate limits with proper retry logic
- **Documentation**: Reference appropriate API docs in `docs/api-references/`

## 📚 Learning Resources

- **API References**: See `docs/api-references/` for complete API documentation
- **Script Templates**: Use `docs/templates/` for standardized starting points  
- **Best Practice Guides**: Check `docs/guides/` for detailed procedures
- **Testing Examples**: Review `tests/` directory for testing patterns

## 🚀 Quick Start

1. **Clone Repository**: `git clone [repository-url]`
2. **Load Profile**: PowerShell will automatically load core modules  
3. **Browse Scripts**: Navigate organized `scripts/` directory by domain
4. **Run Tests**: Use `tests/validation-scripts/` to verify environment
5. **Create Scripts**: Copy from `docs/templates/` and customize

## 🔄 Change Management

All changes are tracked in `CHANGELOG.md` with detailed audit information. The repository follows semantic versioning and maintains comprehensive change history including:
- Script modifications and enhancements
- Security fixes and credential updates  
- Folder structure reorganization
- API integration updates

---

*For questions or contributions, please refer to the individual script documentation or contact the repository maintainer.*
