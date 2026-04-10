# PowerShell Enterprise Library Changelog

All notable changes to this **enterprise-grade PowerShell library** are documented in this file following **security audit and compliance requirements**.

## 🔐 **Security Classification**: All changes documented for audit trail compliance

## [3.3.0] - 2026-04-10 - Infrastructure Automation Roadmap and Scaffold

### Added
- Added `docs/guides/INFRASTRUCTURE_AUTOMATION_ROADMAP.md` to define a phased delivery plan for Active Directory, PKI, SCCM, validation, and CI expansion.
- Added `scripts/infrastructure/` with a manifest-driven scaffold for future day-0 and day-1 automation.
- Added `scripts/infrastructure/Infrastructure-Common.ps1` for shared logging, manifest loading, and preflight helper functions.
- Added `scripts/infrastructure/Invoke-InfrastructureBootstrap.ps1` as a phased orchestration entry point for Active Directory, PKI, and SCCM scaffolds.
- Added `scripts/infrastructure/config/Environment.Baseline.template.psd1` as the tracked baseline manifest template.
- Added `scripts/infrastructure/config/Environment.lab.psd1` as a fuller lab manifest covering Active Directory, PKI, SCCM, networking, and service-account placeholders.
- Added initial scaffold scripts for Active Directory, PKI, and SCCM validation and build-preview workflows.
- Added `scripts/infrastructure/active-directory/New-ADBaselineOUs.ps1` for manifest-driven baseline OU creation.
- Added `scripts/infrastructure/active-directory/New-ADBaselineGroups.ps1` for manifest-driven baseline group creation.
- Added `scripts/infrastructure/active-directory/New-ADBaselineGpos.ps1` for manifest-driven baseline GPO creation and linking.
- Added `scripts/infrastructure/config/Environment.SCCM.template.ps1` as a variable-driven SCCM-focused manifest template.
- Added `scripts/infrastructure/sccm/New-SccmBoundaryModel.ps1` for manifest-driven SCCM boundary and boundary-group creation.
- Added `scripts/infrastructure/sccm/New-SccmBaselineCollections.ps1` for manifest-driven SCCM baseline device collection creation.

### Changed
- Expanded `scripts/infrastructure/active-directory/Test-ADDomainHealth.ps1` from a placeholder into a working validator with domain, forest, domain-controller, SYSVOL, and optional diagnostic command checks.
- Expanded `scripts/infrastructure/active-directory/Test-ADDomainHealth.ps1` further with DNS, FSMO, time-service, and SYSVOL replication signal checks.
- Implemented `scripts/infrastructure/active-directory/Install-FirstDomainController.ps1` as a manifest-driven preflight and promotion workflow with optional feature installation and `Install-ADDSForest` execution support.
- Expanded `scripts/infrastructure/sccm/Test-SccmSiteHealth.ps1` with SQL reachability, management point, software update point, distribution-point, boundary, and boundary-group validation driven by the manifest.
- Expanded `scripts/infrastructure/sccm/Test-SccmSiteHealth.ps1` further with standard-collection and source-path validation driven by the manifest.
- Expanded `scripts/infrastructure/sccm/Test-SccmSiteHealth.ps1` to validate boundary-group boundary references from the manifest.
- Expanded `scripts/infrastructure/sccm/Test-SccmSiteHealth.ps1` with optional live Configuration Manager provider checks for boundaries, boundary groups, memberships, collections, and collection rules.
- Expanded `scripts/infrastructure/Infrastructure-Common.ps1` to support both `.psd1` and `.ps1` manifest files.
- Expanded `scripts/infrastructure/sccm/New-SccmBoundaryModel.ps1` with live boundary-group membership reconciliation.
- Expanded `scripts/infrastructure/sccm/New-SccmBaselineCollections.ps1` with query, include, and exclude membership-rule support.

### Documentation
- Updated `README.md` to index the new infrastructure automation area and roadmap guide.

## [3.2.0] - 2026-04-10 - Script Hardening, Cleanup, and PKI Workflow Expansion

### Added
- Added `scripts/Certificates/Install-PKICertificateServer.ps1` for offline PKI server preparation and CSR generation workflows.
- Added `scripts/Certificates/Install-PKICertificateResponse.ps1` for certificate response retrieval, packaging, and installation workflows.

### Changed
- Refactored multiple certificate, SCCM, Active Directory, EPM automation, IIS, Citrix, Excel, and system-administration scripts for improved parameter handling and safer execution patterns.
- Updated several Jira and endpoint-management automation scripts to use clearer script-scoped configuration values and more consistent logging function names.
- Expanded enterprise-style handling in key system-administration scripts such as Windows feature review, file lock analysis, weather reporting, malware inspection, file transfer, and server inventory collection.
- Simplified or modernized older scripts including date parsing, communication, and reporting helpers.
- Renamed the Zabbix patch-check script from `pet_check_windows_patch.ps1` to `check_windows_patch.ps1`.

### Removed
- Removed older analysis-report Markdown files under `docs/analysis-reports/` that no longer matched the active repository state.
- Removed obsolete duplicate or superseded scripts including `Ask_For_a_date_and_convert_it_to_datetime.ps1` and `Client_Nuke_Malware.ps1`.

### Documentation
- Updated repository and script-area Markdown files to better match the current folder layout and maintained script set.

## [3.1.0] - 2025-10-12 - Security Hardening & Compliance Enhancement

### 🔐 **CRITICAL SECURITY UPDATES**
- **HARDCODED DATA ELIMINATION**: Removed all company-specific hardcoded values across entire repository
- **PARAMETER SECURITY**: Implemented comprehensive parameterization for all environment-specific data
- **CREDENTIAL SECURITY**: Enhanced secure credential management with audit trail compliance
- **ERROR SANITIZATION**: Implemented information disclosure protection in all error messages
- **AUDIT COMPLIANCE**: Added mandatory audit logging for all sensitive operations

### 📋 **COMPLIANCE FRAMEWORK**
- **GDPR COMPLIANCE**: Enhanced data protection with classification system (PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED)
- **SOX COMPLIANCE**: Implemented comprehensive audit trails for financial data operations
- **REGULATORY STANDARDS**: Added documentation requirements for security impact analysis
- **DATA MINIMIZATION**: Implemented privacy-first design principles

## [3.0.0] - 2025-10-10 - Enterprise User Management & GDPR Compliance

### 🎯 **ENTERPRISE USER LIFECYCLE MANAGEMENT**
- **Enhanced** `Manage-JiraUserLifecycle.ps1` with **ZERO HARDCODED VALUES** policy compliance
- **Implemented** secure multi-method user discovery with parameterized authentication
- **Added** project lead conflict resolution with **audit trail compliance**
- **Integrated** GDPR-compliant anonymization with **data protection standards**
- **Enhanced** batch processing with **security event logging** and outcome categorization

#### **🔍 Advanced User Discovery Features:**
- **Multi-API Search**: 10+ different JIRA API endpoints for comprehensive user discovery
- **Inactive User Detection**: Specialized search for already disabled users with `includeInactive=true`
- **Comprehensive Fallback**: Retrieves up to 2000 users and filters by domain when standard searches fail
- **Domain Analysis**: Real-time email domain breakdown and user status reporting

#### **⚖️ Project Lead Conflict Resolution:**
- **Automatic Detection**: Identifies project leadership conflicts before user disable operations
- **Configurable Transfer**: `-NewProjectLead` parameter for specifying content ownership successor
- **Multi-Format Compatibility**: Enhanced payload formats for different JIRA versions
- **Audit Trail**: Complete logging of project leadership transfers for compliance

#### **🛡️ GDPR-Compliant Anonymization:**
- **Content Ownership Transfer**: Proper `newOwnerKey` parameter implementation for anonymization API
- **Eligibility Validation**: Pre-anonymization checks to ensure users can be safely anonymized
- **Progress Monitoring**: Real-time tracking of anonymization process with timeout handling
- **Compliance Reporting**: Detailed audit trails for regulatory compliance requirements

#### **📊 Enhanced Enterprise Reporting:**
- **Outcome Categorization**: Separate tracking of successful, failed, and manual intervention users
- **Optional Debug Logging**: `-EnableDebugLogging` parameter for troubleshooting without log flooding
- **Status Transparency**: Clear indication of ACTIVE vs INACTIVE user processing modes
- **CSV Export Capability**: Structured reporting for enterprise audit requirements

### 🔧 **DEVELOPER EXPERIENCE IMPROVEMENTS**
- **Clean Output**: Debug logging now optional to prevent log flooding in production
- **Enhanced Documentation**: Comprehensive API reference and user management guides
- **Version Control**: Updated version to 3.0 with proper date and authorship attribution

## [2.0.0] - 2025-10-09 - Major Reorganization & Structure Implementation

### 🗂️ **BREAKING CHANGES - Complete Folder Restructure**
- **Replaced** flat `Scripts/` folder structure with modern domain-organized hierarchy
- **Migrated** all scripts to new categorized locations using systematic robocopy operations
- **Updated** PowerShell profile to work with new `core/` module loading structure
- **Enhanced** Copilot instructions with modern security patterns and best practices

#### **New Folder Structure Implemented:**
```
core/
├── authentication/     # Credential management, AD auth, Office 365 connections
├── utilities/         # General utility functions, system monitoring
└── reporting/         # System reporting, hardware specifications

scripts/
├── exchange/          # Office 365, Exchange mailbox management (was: Scripts/Mailbox/)
├── active-directory/  # User lifecycle, group management (was: Scripts/AD/)
├── communication/     # Lync/Teams, email automation (was: Scripts/LYNC/)
├── atlassian/         # Jira, Confluence, OpsGenie (was: Scripts/Atlassian/)
├── system-administration/ # IIS, monitoring, security (was: Scripts/IIS/, Scripts/System/)
├── network/           # Connectivity testing (was: Scripts/Network/)
├── reporting/         # Excel integration (was: Scripts/Excel/)
└── integration/       # Database connections (was: Scripts/DB/)

docs/
├── api-references/    # Complete API documentation
├── guides/           # Procedures and best practices
└── templates/        # Script templates (was: Scripts/Template.ps1)

tools/
├── development/      # Script signing, optimization (was: Scripts/SignScripts.ps1, OptimizeScripts.ps1)
├── installation/     # Module installation (was: Scripts/Install_Modules.ps1)
└── legacy/          # Archived configurations

data/
├── config/          # Configuration files
├── logs/           # Execution logs
└── reports/        # Generated reports

tests/
├── unit-tests/         # Individual function tests
├── integration-tests/  # End-to-end workflow tests
└── validation-scripts/ # Script validation and compliance

archive/               # Deprecated files and old structure remnants
```

#### **Migration Summary:**
- **✅ 20 AD scripts** → `scripts/active-directory/user-management/`
- **✅ 4 IIS scripts** → `scripts/system-administration/monitoring/`
- **✅ 1 VMWare script** → `scripts/system-administration/maintenance/`
- **✅ 4 Certificate scripts** → `scripts/system-administration/security/`
- **✅ 2 Citrix scripts** → `scripts/system-administration/maintenance/`
- **✅ 2 Database scripts** → `scripts/integration/database/`
- **✅ 6 Excel scripts** → `scripts/reporting/excel/`
- **✅ 1 Task Scheduler script** → `scripts/system-administration/automation/`
- **✅ 1 Restore script** → `scripts/system-administration/backup/`
- **✅ 86 Atlassian scripts** → maintained existing organization under `scripts/atlassian/`
- **✅ 19 Exchange/Mailbox scripts** → `scripts/exchange/mailbox-management/`
- **✅ Network scripts** → `scripts/network/connectivity-testing/`

### 🔧 **Enhanced Infrastructure**
- **Updated** PowerShell profile with new `core/` recursive loading and colorized feedback
- **Modernized** Copilot instructions with security patterns, API examples, UI/UX standards
- **Preserved** existing `autoload/` for backward compatibility
- **Cleaned up** old `Scripts/` folder after successful migration

---

## [1.9.0] - 2025-10-08 - Security Hardening & Advanced Script Enhancements

### 🔒 **Security Fixes**
- **Replaced** all hardcoded credentials with secure PowerShell credential management
- **Implemented** secure API key storage using Export-Clixml encryption for OpsGenie scripts
- **Added** secure credential prompts and persistent encrypted storage for Jira scripts
- **Scanned** and remediated security vulnerabilities across entire repository

### ✨ **Enhanced Scripts**
- **Get-Weather.ps1**: Complete rewrite with secure API key management, parameter validation, interactive prompts
- **FindProcessForFileInUse.ps1**: Added dual detection methods, CSV export, verbose logging, enhanced error handling
- **TestHTTPSConnections.ps1**: Implemented categorized endpoint testing, real-time progress, analytics, CSV reporting

### 🎯 **Best Practices Implementation**
- **Advanced parameter validation** with comprehensive error handling
- **Colorized user interfaces** throughout all scripts
- **Comprehensive error handling** with meaningful user messages

---

## [1.8.0] - 2025-10-07 - PowerShell Best Practices & API Documentation

### ✅ **Zero Errors Achievement**
- **Validated** all 1,400+ PowerShell scripts now 100% error-free
- **Fixed** 750+ PowerShell best practice violations
- **Standardized** aliases: `gci→Get-ChildItem`, `select→Select-Object`, `where→Where-Object`

### 📋 **API Documentation**
- **Created** comprehensive `ATLASSIAN_API_REFERENCE.md` with complete API endpoints
- **Documented** Jira Cloud REST API v3, Jira On-Prem REST API v2, Confluence REST API, OpsGenie API v2
- **Provided** PowerShell code samples with authentication examples

### 🔧 **Enhanced Scripts**
- **Windows-Upgrade-All-Apps.ps1**: Added proper error handling, colorized output, user confirmation
- **Graceful_Jira_Restart_v1.1.ps1**: Fixed URI formatting, added timeout and error handling
- **Clean-Teamviewer-of-Old-PCs.ps1**: Fixed incomplete API URIs, added proper error handling

### 🎨 **UI Improvements**
- **Added** color coding throughout all scripts for better user experience
- **Implemented** try/catch blocks with meaningful error messages
- **Enhanced** user-friendly status messages and progress indicators

---

## [1.7.0] - 2025-10-06 - Comprehensive Script Audit & Fixes

### 🚨 **Critical Issues Fixed**

#### **Active Directory Scripts**
- **`Get-LockedOutLocation.ps1`**: Fixed missing PDCEmulator filter, empty Write-Verbose statements, malformed Write-Progress parameters
- **`GetListOfADGroupMembers.ps1`**: Complete rebuild as proper `Get-ADGroupMembers` function with comprehensive help documentation

#### **System Scripts**
- **`Get-Weather.ps1`**: Fixed empty API key variables, missing error messages, incomplete URL construction
- **`Nuke-Malware.ps1`**: Added parameter validation messages and proper error handling
- **`FindProcessForFileInUse.ps1`**: Enhanced with dual detection methods and comprehensive logging

#### **Exchange Scripts**
- **`send_email.ps1`**: Fixed malformed SMTP configuration and credential handling
- **`Get-MailboxForwardingEnabled.ps1`**: Added proper SMTP pattern matching and email domain parsing

#### **Atlassian Scripts (86 scripts total)**
- **`JIRA_EmailUserCleanUp.ps1`**: Fixed missing email credentials and addresses
- **`Graceful_Jira_Restart_v1.1.ps1`**: Set proper ErrorActionPreference value
- **`CreateIssueWith_UserMangementReport.ps1`**: Added meaningful status messages with color coding
- **`JIRA_CleanUpWorkflows.ps1`**: Added proper Jira base URL and credential handling

### 🔄 **Standardization Completed**
- **Renamed** NSG-prefixed files to follow PowerShell Verb-Noun convention:
  - `NSG-IISLogsCleanup.ps1` → `Start-IISLogsCleanup.ps1`
  - `NSG-GetMailboxForwardingEnabled.ps1` → `Get-MailboxForwardingEnabled.ps1`
  - `NSG-GetAllAutomappings.ps1` → `Get-AllAutomappings.ps1`

### 🗑️ **Cleanup Actions**
- **Removed** duplicate files (`ReadFromExcel.ps1` - identical to `import_from_excel.ps1`)
- **Fixed** malformed scripts with missing function definitions
- **Standardized** unapproved verbs: `Load-Module` → `Import-ModuleIfAvailable` across 18+ scripts

---

## [1.6.0] - 2025-10-05 - Foundation & Template Fixes

### 🔧 **Core Infrastructure**
- **`Template.ps1`**: Fixed incomplete `$Line =` assignment, variable name mismatches (`$slogfile` vs `$logfile`)
- **`README.md`**: Created comprehensive documentation from empty file
- **Profile scripts**: Fixed empty variable assignments and missing PSDrive configurations

### 📚 **Documentation**
- **Added** folder structure explanations
- **Created** usage examples and development guidelines
- **Documented** function naming conventions and API integration patterns

### 🏗️ **Function Standardization**
- **Renamed** functions to follow PowerShell conventions:
  - `NSG-GetMailboxAutomapping` → `Get-MailboxAutomapping`
  - `NSG-GetUserAutomapping` → `Get-UserAutomapping`
- **Enhanced** `Install_Modules.ps1` with informative messages and color coding

---

## [1.5.0] - 2025-10-04 - Initial Repository Restoration

### 📦 **Major Recovery**
- **Restored** all 1,571 files from previous repository states
- **Validated** file integrity and PowerShell syntax across entire codebase
- **Established** git workflow with descriptive commit messages

### 🔍 **Initial Assessment**
- **Identified** 750+ PowerShell best practice violations
- **Catalogued** security issues with hardcoded credentials
- **Documented** script functionality and dependencies

---

## Migration Guide

### **Updating Script References**

If you have scripts that reference the old folder structure, update them as follows:

```powershell
# OLD REFERENCES (Update these):
. "C:\PS\Scripts\AD\Get-LockedOutLocation.ps1"
. "C:\PS\Scripts\Mailbox\Get-MailboxAutomapping.ps1"
. "C:\PS\Scripts\Atlassian\Cloud\DisableUser.ps1"
. "C:\PS\Scripts\Template.ps1"

# NEW REFERENCES (Use these):
. "C:\PS\scripts\active-directory\Get-LockedOutLocation.ps1"
. "C:\PS\scripts\exchange\Get-MailboxAutomapping.ps1"
. "C:\PS\scripts\atlassian\cloud\DisableUser.ps1"
. "C:\PS\docs\templates\Template.ps1"
```

### **PowerShell Profile Updates**

The PowerShell profile has been automatically updated to work with the new structure. If you have custom profile modifications, ensure they reference:

- **Core modules**: `C:\PS\core\**\*.ps1` (automatically loaded)
- **Utility functions**: Available after profile loads
- **Script paths**: Updated to include new `scripts\` subdirectories in PATH

---

## Breaking Changes Summary

### **Folder Structure** (v2.0.0)
- **Complete reorganization** from flat structure to domain-organized hierarchy
- **Scripts moved** from `Scripts\[Category]\` to `scripts\[domain]\[category]\`
- **Core functions** centralized in `core\` directory
- **Documentation** organized in `docs\` with proper categorization

### **Function Names** (v1.7.0)
- **NSG-prefixed functions** renamed to standard PowerShell Verb-Noun format
- **Load-Module** replaced with approved `Import-ModuleIfAvailable` verb

### **Security Model** (v1.9.0)
- **Hardcoded credentials removed** - scripts now require proper credential input
- **API keys** must be configured securely using provided credential management functions

---

*This changelog follows [Keep a Changelog](https://keepachangelog.com/) format and [Semantic Versioning](https://semver.org/) principles.*