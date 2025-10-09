# GitHub Copilot Instructions for PowerShell Scripts Repository

## 🎯 **Repository Overview**
This is a comprehensive PowerShell automation library containing scripts for:
- **Atlassian Products** (Jira Cloud/On-Prem, Confluence, OpsGenie)
- **Office 365 & Exchange** (User management, mailbox operations, permissions)
- **Active Directory** (User lifecycle, group management, security)
- **System Administration** (Monitoring, maintenance, troubleshooting)
- **Network Operations** (Connectivity testing, infrastructure management)

## 📁 **Reorganized Folder Structure**
- **`core/`** - Reusable modules and functions
  - `authentication/` - Credential management, AD authentication
  - `utilities/` - General utility functions
  - `reporting/` - System reporting and monitoring functions
- **`scripts/`** - Main script collection organized by domain
  - `exchange/` - Exchange & Office 365 operations
  - `active-directory/` - AD user/group management
  - `communication/` - Lync/Teams/Email automation
  - `atlassian/` - Jira, Confluence, OpsGenie integration
  - `system-administration/` - General system tasks
  - `network/` - Network operations and testing
- **`tools/`** - Development and utility tools
  - `development/` - Script signing, optimization
  - `installation/` - Module installation scripts
  - `legacy/` - Archived tools and configurations
- **`docs/`** - Documentation and references
  - `api-references/` - API documentation and guides
  - `guides/` - How-to guides and procedures
  - `templates/` - Script templates and examples
- **`data/`** - Data files and configurations
- **`tests/`** - Test scripts and validation
- **`archive/`** - Historical content (PowerShell-Master, deprecated scripts)

## Key Scripts
- **Jira User Management**: Scripts for bulk deleting and anonymizing Jira users, replacing usernames and emails, and integrating with Azure AD or on-prem Active Directory.
- **System Monitoring**: Scripts for checking system uptime, listing running services, and fetching weather data.
- **Automation Tasks**: Scripts for installing Jenkins agents, creating event logs, and managing user accounts.

## 📋 **PowerShell Best Practices to Follow**

### **1. Security Standards**
```powershell
# ✅ GOOD: Use secure credential handling
$creds = Get-Credential
$secureApiKey = Read-Host "Enter API key" -AsSecureString

# ❌ AVOID: Hardcoded credentials
$password = "mypassword123"
$apiKey = "abc-123-xyz"
```

### **2. Parameter Validation**
```powershell
# ✅ GOOD: Comprehensive parameter validation
param(
    [Parameter(Mandatory=$true, HelpMessage="Enter server name")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 30
)
```

### **3. Error Handling**
```powershell
# ✅ GOOD: Comprehensive error handling
try {
    $result = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    Write-Host "✅ Success: Operation completed" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log -Level ERROR -Message $_.Exception.Message
}
```

### **4. User Experience**
```powershell
# ✅ GOOD: Colorized, informative output
Write-Host "🚀 Starting process..." -ForegroundColor Cyan
Write-Host "📊 Processing 25 items..." -ForegroundColor Yellow
Write-Host "✅ Completed successfully!" -ForegroundColor Green

# ❌ AVOID: Plain or confusing output
Write-Host "Starting"
Write-Host "Done"
```

## Developer Workflows
- **Testing**: Use `Pester` for unit testing PowerShell scripts. Example test files can be found in the `Powershell-Master/scripts/` directory.
- **Debugging**: Leverage the `Write-Debug` cmdlet for inline debugging. Ensure debug messages are meaningful and actionable.
- **Script Signing**: Use the `SignScripts.ps1` script in the `Scripts/` folder to sign PowerShell scripts before deployment.

## API Integrations
- Replace `Invoke-RestMethod` with `curl` for API calls where possible.
- Ensure API calls include proper authentication and error handling.
- Refer to `autoload/Connect-Office365Services.ps1` for examples of API integration patterns.

## 🛠️ **Code Patterns to Use**

### **API Integration Pattern**
```powershell
# Standard API call with error handling
$headers = @{
    'Authorization' = "Bearer $apiToken"
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method $method -Headers $headers -Body $body
    return $response
} catch {
    Write-Host "❌ API call failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
```

### **Logging Pattern**
```powershell
# Consistent logging across all scripts
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}
```

### **Progress Reporting**
```powershell
# Progress indicators for long operations
$totalItems = $items.Count
for ($i = 0; $i -lt $totalItems; $i++) {
    $percentComplete = [math]::Round(($i / $totalItems) * 100)
    Write-Progress -Activity "Processing Items" -Status "Item $($i+1) of $totalItems" -PercentComplete $percentComplete
}
Write-Progress -Activity "Processing Items" -Completed
```

## 📁 **Repository Structure Guidelines**

### **File Organization**
- **`core/`** - Reusable functions and modules
- **`scripts/`** - Main script collection organized by domain
- **`tools/`** - Utility scripts and helper tools
- **Documentation** - Keep README.md current with recent changes

### **Naming Conventions**
- **Functions:** `Verb-Noun` (Get-UserInfo, Set-MailboxPermission)
- **Scripts:** Descriptive names (CreateJiraIssue.ps1, TestNetworkConnectivity.ps1)
- **Variables:** Clear, descriptive ($mailboxPermissions, $apiResponse)

## 🔧 **Common Issues to Fix**

### **1. Incomplete Assignments**
```powershell
# ❌ AVOID: Empty assignments
$variable =
$apiKey =

# ✅ FIX: Complete assignments or use proper validation
$variable = "default-value"
if (-not $apiKey) { $apiKey = Read-Host "Enter API key" }
```

### **2. Poor Error Messages**
```powershell
# ❌ AVOID: Generic errors
catch { Write-Error "Error occurred" }

# ✅ FIX: Specific, actionable errors
catch {
    Write-Host "❌ Failed to connect to $serverName : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Check network connectivity and credentials" -ForegroundColor Yellow
}
```

### **3. Missing Parameter Help**
```powershell
# ❌ AVOID: No help text
param([string]$Name)

# ✅ FIX: Comprehensive help
param(
    [Parameter(Mandatory=$true, HelpMessage="Enter user display name")]
    [ValidateNotNullOrEmpty()]
    [string]$Name
)
```

## 🎨 **UI/UX Standards**

### **Color Coding**
- 🔵 **Cyan**: Process start, headers, information
- 🟡 **Yellow**: Warnings, prompts, in-progress status
- 🟢 **Green**: Success, completion, positive results
- 🔴 **Red**: Errors, failures, critical issues
- ⚪ **White**: Standard output, data display
- 🔘 **Gray**: Secondary information, metadata

### **Icons and Formatting**
```powershell
Write-Host "🚀 Starting deployment process..." -ForegroundColor Cyan
Write-Host "⚠️  Warning: This will modify production data" -ForegroundColor Yellow
Write-Host "✅ Deployment completed successfully" -ForegroundColor Green
Write-Host "❌ Deployment failed with errors" -ForegroundColor Red
Write-Host "📊 Processing 150 items..." -ForegroundColor White
Write-Host "💡 Tip: Use -WhatIf to preview changes" -ForegroundColor Gray
```

## 📚 **API Documentation Reference**

When working with API integrations, refer to:
- **`docs/api-references/ATLASSIAN_API_REFERENCE.md`** - Complete Atlassian API documentation
- **Microsoft Graph API** - For Office 365/Azure AD operations
- **Exchange Online PowerShell** - For mailbox and email operations

## 🧪 **Testing Guidelines**

### **WhatIf Implementation**
```powershell
param([switch]$WhatIf)

if ($WhatIf) {
    Write-Host "🔍 WhatIf Mode: Would delete user $userName" -ForegroundColor Yellow
    return
}
# Actual operation
```

### **Validation Checks**
```powershell
# Pre-flight checks
if (-not (Test-Path $filePath)) {
    Write-Host "❌ File not found: $filePath" -ForegroundColor Red
    return
}

if (-not $apiKey) {
    Write-Host "❌ API key required for this operation" -ForegroundColor Red
    return
}
```

## Contribution Guidelines
- Follow the development guidelines outlined above.
- Test scripts thoroughly using `Pester`.
- Document any new scripts or updates in the `README.md` files.

## Notes for AI Agents
- Focus on improving error handling, logging, and modularization in scripts.
- Ensure compatibility with both cloud and on-prem environments where possible.
- Prioritize the use of `curl` for API calls.
- Add or update documentation as needed.
- Refer to `autoload/` for reusable functions and modules.
- Ensure all scripts include appropriate comments and documentation.
- Maintain consistent formatting and style across all scripts.
- Include error handling and logging in all scripts.
- Use `Pester` for testing and ensure scripts are well-tested before committing.
- Consider performance implications and optimize scripts for efficiency.
- Ensure scripts are secure, especially when handling sensitive data or credentials.
- Follow best practices for PowerShell scripting.
- Use version control effectively, with clear commit messages and branches for new features or fixes.
- Document any new scripts or updates in the `README.md` files.
- Regularly review and update scripts to ensure they remain relevant and effective.
- Ensure all scripts are properly documented and include usage examples.

## Contact
For any questions or contributions, please contact the repository maintainer.