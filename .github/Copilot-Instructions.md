# GitHub Copilot Instructions for PowerShell Scripts Repository

## 🎯 **Repository Overview**
This is a comprehensive PowerShell automation library containing enterprise-grade scripts for:
- **Collaboration Platforms** (Issue tracking, documentation systems, incident management)
- **Cloud & Email Services** (User management, mailbox operations, permissions)
- **Directory Services** (User lifecycle, group management, security)
- **System Administration** (Monitoring, maintenance, troubleshooting)
- **Network Operations** (Connectivity testing, infrastructure management)

## 🔐 **Security & Compliance Requirements**

### **Data Protection & Privacy**
- **NO hardcoded credentials, API keys, or sensitive data**
- **NO company-specific names, domains, or identifiers**
- Use generic placeholders (e.g., `contoso.com`, `example.org`)
- Implement secure credential management using `Get-Credential` or Azure Key Vault
- All sensitive operations must include audit logging

### **Code Security Standards**
- Validate all user inputs and parameters
- Use secure communication protocols (HTTPS/TLS)
- Implement proper error handling without exposing sensitive information
- Follow principle of least privilege for all operations

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

### **1. Security & Parameterization Standards**
```powershell
# ✅ GOOD: Secure credential handling with parameters
param(
    [Parameter(Mandatory=$false, HelpMessage="Username for authentication")]
    [string]$Username,

    [Parameter(Mandatory=$false, HelpMessage="Use Windows Authentication")]
    [switch]$UseWindowsAuth,

    [Parameter(Mandatory=$false, HelpMessage="Path to credential file")]
    [ValidateScript({Test-Path $_})]
    [string]$CredentialPath
)

# Secure credential retrieval
if ($CredentialPath) {
    $creds = Import-Clixml -Path $CredentialPath
} elseif ($Username) {
    $creds = Get-Credential -UserName $Username
} else {
    $creds = Get-Credential
}

# ❌ AVOID: Any hardcoded values
$companyName = "ACME Corp"           # Use parameter instead
$serverName = "prod-server-01"       # Use parameter instead
$apiKey = "abc-123-xyz"             # Use secure storage instead
$domain = "@company.com"            # Use parameter instead
```

### **2. Generic Parameterization Pattern**
```powershell
# ✅ REQUIRED: All company-specific values as parameters
param(
    [Parameter(Mandatory=$true, HelpMessage="Organization domain (e.g., contoso.com)")]
    [ValidateNotNullOrEmpty()]
    [string]$OrganizationDomain,

    [Parameter(Mandatory=$true, HelpMessage="Server hostname or IP")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName,

    [Parameter(Mandatory=$false, HelpMessage="Environment (Dev, Test, Prod)")]
    [ValidateSet("Dev", "Test", "Prod")]
    [string]$Environment = "Test",

    [Parameter(Mandatory=$false, HelpMessage="Timeout in seconds")]
    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 30
)
```

### **3. Configuration File Pattern**
```powershell
# ✅ GOOD: External configuration for environment-specific values
$configPath = Join-Path $PSScriptRoot "config.json"
if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
} else {
    Write-Warning "Configuration file not found. Using default values."
    $config = @{
        DefaultDomain = "example.org"
        DefaultTimeout = 30
        DefaultEnvironment = "Test"
    }
}
```

### **4. Secure Error Handling & Logging**
```powershell
# ✅ REQUIRED: Secure logging with audit trail
# Audit logs MUST be placed next to the script file (in the same directory), not in a central logs directory. This ensures portability and consistent access regardless of execution location.
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory=$false)]
        [switch]$Sensitive,

        [Parameter(Mandatory=$false)]
        [string]$LogPath = (Join-Path $PSScriptRoot "ScriptAudit.log")
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $sessionId = $script:SessionId ?? (New-Guid).ToString().Substring(0,8)

    # Sanitize message for display (remove sensitive data)
    $displayMessage = $Message
    if ($script:OrganizationDomain) {
        $displayMessage = $displayMessage -replace $script:OrganizationDomain, "[DOMAIN]"
    }

    $logEntry = "[$timestamp] [$sessionId] [$Level] $displayMessage"

    # Display non-sensitive logs
    if (-not $Sensitive) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "AUDIT" { "Cyan" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    # Always log full message to file (including sensitive data for troubleshooting)
    $fullLogEntry = "[$timestamp] [$sessionId] [$Level] [$env:USERNAME] $Message"
    try {
        Add-Content -Path $LogPath -Value $fullLogEntry -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Action,

        [Parameter(Mandatory=$false)]
        [string]$Target,

        [Parameter(Mandatory=$true)]
        [string]$User,

        [Parameter(Mandatory=$false)]
        [string]$Error,

        [Parameter(Mandatory=$false)]
        [hashtable]$AdditionalData
    )

    $auditEntry = @{
        Timestamp = Get-Date -Format "o"
        SessionId = $script:SessionId
        Action = $Action
        User = $User
        Target = $Target
        Error = $Error
        ComputerName = $env:COMPUTERNAME
        ScriptName = $MyInvocation.ScriptName
        AdditionalData = $AdditionalData
    }

    $auditJson = $auditEntry | ConvertTo-Json -Compress
    Write-Log -Message $auditJson -Level "AUDIT" -Sensitive $true
}
- [ ] Proper error handling without information disclosure
- [ ] Comprehensive parameter validation
- [ ] Audit logging implemented
- [ ] Security documentation complete

### **Script Signing & Deployment**
- All production scripts must be code-signed
- Use certificate-based authentication where possible
- Implement script integrity verification

## 🛠️ **Secure Code Patterns**

### **Parameterized API Integration Pattern**
```powershell
# ✅ REQUIRED: Secure API pattern with full parameterization
param(
    [Parameter(Mandatory=$true, HelpMessage="API base URL (e.g., https://api.example.com)")]
    [ValidateScript({$_ -match '^https://'})]
    [string]$ApiBaseUrl,

    [Parameter(Mandatory=$true, HelpMessage="API endpoint path")]
    [string]$EndpointPath,

    [Parameter(Mandatory=$false, HelpMessage="Use stored credentials")]
    [switch]$UseStoredCredentials,

    [Parameter(Mandatory=$false, HelpMessage="Request timeout in seconds")]
    [ValidateRange(5, 300)]
    [int]$TimeoutSeconds = 30
)

# Secure token retrieval
if ($UseStoredCredentials) {
    $apiToken = Get-StoredApiToken -Service $ServiceName
} else {
    $secureToken = Read-Host "Enter API token" -AsSecureString
    $apiToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))
}

# Construct full URL
$fullUrl = "$ApiBaseUrl/$EndpointPath".Replace("//", "/")

$headers = @{
    'Authorization' = "Bearer $apiToken"
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
    'User-Agent' = 'PowerShellScript/1.0'
}

try {
    $response = Invoke-RestMethod -Uri $fullUrl -Method $Method -Headers $headers -Body $Body -TimeoutSec $TimeoutSeconds
    Write-AuditLog -Action "API_SUCCESS" -Endpoint $EndpointPath -User $env:USERNAME
    return $response
} catch {
    $sanitizedUrl = $fullUrl -replace $OrganizationDomain, "[DOMAIN]"
    Write-Host "❌ API call failed to $sanitizedUrl : $($_.Exception.Message)" -ForegroundColor Red
    Write-AuditLog -Action "API_FAILED" -Endpoint $EndpointPath -User $env:USERNAME -Error $_.Exception.Message
    throw
} finally {
    # Clear sensitive variables
    $apiToken = $null
    $secureToken = $null
}
```

### **Secure Logging & Audit Pattern**
```powershell
# ✅ REQUIRED: Secure logging with audit trail
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory=$false)]
        [switch]$Sensitive,

        [Parameter(Mandatory=$false)]
        [string]$LogPath = $script:LogFile
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $sessionId = $script:SessionId ?? (New-Guid).ToString().Substring(0,8)

    # Sanitize message for display (remove sensitive data)
    $displayMessage = $Message
    if ($script:OrganizationDomain) {
        $displayMessage = $displayMessage -replace $script:OrganizationDomain, "[DOMAIN]"
    }

    $logEntry = "[$timestamp] [$sessionId] [$Level] $displayMessage"

    # Display non-sensitive logs
    if (-not $Sensitive) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "AUDIT" { "Cyan" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    # Always log full message to file (including sensitive data for troubleshooting)
    $fullLogEntry = "[$timestamp] [$sessionId] [$Level] [$env:USERNAME] $Message"
    try {
        Add-Content -Path $LogPath -Value $fullLogEntry -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

# Audit-specific logging function
function Write-AuditLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Action,

        [Parameter(Mandatory=$false)]
        [string]$Target,

        [Parameter(Mandatory=$true)]
        [string]$User,

        [Parameter(Mandatory=$false)]
        [string]$Error,

        [Parameter(Mandatory=$false)]
        [hashtable]$AdditionalData
    )

    $auditEntry = @{
        Timestamp = Get-Date -Format "o"
        SessionId = $script:SessionId
        Action = $Action
        User = $User
        Target = $Target
        Error = $Error
        ComputerName = $env:COMPUTERNAME
        ScriptName = $MyInvocation.ScriptName
        AdditionalData = $AdditionalData
    }

    $auditJson = $auditEntry | ConvertTo-Json -Compress
    Write-Log -Message $auditJson -Level "AUDIT" -Sensitive $true
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

## � **Critical Security Fixes Required**

### **1. Eliminate All Hardcoded Values**
```powershell
# ❌ CRITICAL: Hardcoded company data - MUST BE FIXED
$serverName = "PROD-SQL-01"
$domain = "@acmecorp.com"
$apiKey = "sk-1234567890abcdef"
$companyName = "Acme Corporation"

# ✅ REQUIRED FIX: Parameterize everything
param(
    [Parameter(Mandatory=$true, HelpMessage="Server hostname")]
    [string]$ServerName,

    [Parameter(Mandatory=$true, HelpMessage="Organization domain (e.g., @contoso.com)")]
    [string]$Domain,

    [Parameter(Mandatory=$true, HelpMessage="Organization display name")]
    [string]$OrganizationName
)

# For API keys - never hardcode, always prompt or use secure storage
$apiKey = Get-SecureApiKey -ServiceName $ServiceName
```

### **2. Sanitize All Output and Errors**
```powershell
# ❌ CRITICAL: Exposing sensitive information
catch {
    Write-Error "Failed to connect to prod-db-01.acme.corp with key abc123"
    Write-Host "Error in user processing for john.doe@acmecorp.com"
}

# ✅ REQUIRED FIX: Sanitized error handling
catch {
    $sanitizedError = $_.Exception.Message -replace $OrganizationDomain, "[DOMAIN]" -replace $ServerName, "[SERVER]"
    Write-Host "❌ Connection failed: $sanitizedError" -ForegroundColor Red
    Write-Host "💡 Check network connectivity and authentication" -ForegroundColor Yellow

    # Log full details securely for troubleshooting
    Write-AuditLog -Action "CONNECTION_FAILED" -Target $ServerName -User $env:USERNAME -Error $_.Exception.Message
}
```

### **3. Implement Comprehensive Parameter Validation**
```powershell
# ❌ AVOID: Minimal or no validation
param([string]$Email)

# ✅ REQUIRED: Comprehensive validation and documentation
param(
    [Parameter(
        Mandatory=$true,
        Position=0,
        ValueFromPipeline=$true,
        HelpMessage="Email address in format user@domain.com"
    )]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [ValidateNotNullOrEmpty()]
    [string]$EmailAddress,

    [Parameter(Mandatory=$false, HelpMessage="Validate email domain exists")]
    [switch]$ValidateDomain,

    [Parameter(Mandatory=$false, HelpMessage="Maximum processing time in minutes")]
    [ValidateRange(1, 60)]
    [int]$TimeoutMinutes = 5
)
```

### **4. Data Classification & Protection**
```powershell
# ✅ REQUIRED: Classify and protect data appropriately
$DataClassification = @{
    PUBLIC = @("ServerStatus", "GeneralConfiguration")
    INTERNAL = @("UserLists", "GroupMemberships")
    CONFIDENTIAL = @("EmailAddresses", "PersonalData")
    RESTRICTED = @("Passwords", "ApiKeys", "Tokens")
}

# Implement appropriate handling based on classification
function Process-Data {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DataType,

        [Parameter(Mandatory=$true)]
        $Data
    )

    $classification = Get-DataClassification -DataType $DataType

    switch ($classification) {
        "RESTRICTED" {
            # Never log, minimal processing, immediate cleanup
            Write-AuditLog -Action "RESTRICTED_DATA_ACCESS" -User $env:USERNAME
            # Process without logging content
            $null = $Data  # Clear reference immediately
        }
        "CONFIDENTIAL" {
            # Limited logging, sanitized output
            Write-Log "Processing confidential data type: $DataType" -Sensitive $true
        }
        default {
            Write-Log "Processing $DataType data"
        }
    }
}
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

## 📚 **Compliance & Documentation Requirements**

### **Regulatory Compliance**
- **Data Protection**: GDPR, CCPA, SOX compliance for data handling
- **Audit Trail**: All data access and modifications must be logged
- **Data Retention**: Follow organizational data retention policies
- **Privacy**: Implement data minimization and purpose limitation

### **API Integration Standards**
When working with API integrations, ensure:
- **Authentication**: Use secure authentication methods (OAuth, certificates)
- **Rate Limiting**: Implement proper rate limiting and retry logic
- **Data Validation**: Validate all API responses before processing
- **Error Handling**: Log API errors without exposing sensitive details

### **Required Documentation**
- **API References**: Document all external API dependencies
- **Security Assessment**: Include security impact analysis for each script
- **Compliance Matrix**: Map scripts to applicable regulations and standards
- **Change Log**: Maintain detailed change history with security implications
- **User Guide**: Provide clear instructions for script usage and parameters
- **Developer Guide**: Include coding standards, patterns, and best practices
- **FAQ**: Address common questions and troubleshooting tips
- **Support Information**: Provide contact details for support and escalation
- **Glossary**: Define technical terms and acronyms used in the scripts
- **In-line Documentation**: Use comment-based help for all functions and scripts
- **Examples**: Provide usage examples for complex operations
- **Templates**: Include script templates for common tasks
- **Security Guidelines**: Outline security best practices for script development and usage
- **Testing Procedures**: Document testing strategies and validation steps
- **Backup & Recovery**: Provide guidelines for data backup and recovery processes
- **Versioning**: Implement version control and document version history
- **Licensing**: Include appropriate licensing information for the repository
- **Contribution Guidelines**: Define how to contribute to the repository, including code reviews and security checks
- **Code of Conduct**: Establish a code of conduct for contributors and users
- **Disaster Recovery Plan**: Outline steps for disaster recovery related to script failures or data loss
- **Incident Response Plan**: Provide a plan for responding to security incidents involving the scripts
- **Training Materials**: Include training resources for users and developers
- **Performance Metrics**: Document performance benchmarks and optimization strategies
- **Accessibility Standards**: Ensure scripts and documentation meet accessibility requirements
- **Localization**: Provide guidelines for localization and internationalization if applicable
- **Review Schedule**: Establish a schedule for regular review and updates of scripts and documentation
- **Feedback Mechanism**: Implement a way for users to provide feedback on scripts and documentation
- **Audit Logs**: Ensure audit logs are stored securely and access is controlled
- **Change Management**: Implement change management processes for script updates
- **Compliance Checks**: Regularly review scripts for compliance with policies and regulations
- **Security Reviews**: Conduct periodic security reviews and penetration testing of scripts
- **Data Encryption**: Ensure sensitive data is encrypted in transit and at rest
- **Environment Segregation**: Use separate environments for development, testing, and production
- **Backup Procedures**: Document backup procedures for scripts and configuration files
- **Monitoring & Alerts**: Implement monitoring and alerting for script failures or anomalies


## 🧪 **Security Testing & Validation**

### **Mandatory WhatIf Implementation**
```powershell
# ✅ REQUIRED: WhatIf support for all destructive operations
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [string]$TargetResource,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

if ($PSCmdlet.ShouldProcess($TargetResource, "Delete Operation")) {
    if ($Force -or $PSCmdlet.ShouldContinue("Are you sure?", "Confirm Deletion")) {
        # Perform actual operation
        Write-Log "Executing deletion of $TargetResource"
    }
} else {
    # WhatIf mode - show what would be done
    Write-Host "🔍 WhatIf: Would delete resource [$TargetResource]" -ForegroundColor Yellow
    Write-AuditLog -Action "WHATIF_DELETE" -Target $TargetResource -User $env:USERNAME
}
```

### **Comprehensive Validation Pattern**
```powershell
# ✅ REQUIRED: Multi-level validation
function Test-Prerequisites {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$ValidationRules
    )

    $validationResults = @()

    foreach ($rule in $ValidationRules.GetEnumerator()) {
        try {
            $result = & $rule.Value
            $validationResults += @{
                Rule = $rule.Key
                Passed = $result.Success
                Message = $result.Message
                Severity = $result.Severity ?? "Error"
            }
        } catch {
            $validationResults += @{
                Rule = $rule.Key
                Passed = $false
                Message = "Validation failed: $($_.Exception.Message)"
                Severity = "Critical"
            }
        }
    }

    return $validationResults
}

# Example validation rules
$validationRules = @{
    "FileAccess" = {
        @{ Success = (Test-Path $FilePath); Message = "File accessibility check" }
    }
    "NetworkConnectivity" = {
        @{ Success = (Test-NetConnection $ServerName -Port $Port -WarningAction SilentlyContinue).TcpTestSucceeded; Message = "Network connectivity check" }
    }
    "Permissions" = {
        @{ Success = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator); Message = "Administrative privileges check" }
    }
    "DataIntegrity" = {
        @{ Success = (Get-FileHash $FilePath).Hash -eq $ExpectedHash; Message = "File integrity verification" }
    }
}

$validationResults = Test-Prerequisites -ValidationRules $validationRules
$criticalFailures = $validationResults | Where-Object { -not $_.Passed -and $_.Severity -eq "Critical" }

if ($criticalFailures) {
    Write-Host "❌ Critical validation failures detected:" -ForegroundColor Red
    foreach ($failure in $criticalFailures) {
        Write-Host "  • $($failure.Rule): $($failure.Message)" -ForegroundColor Red
    }
    Write-AuditLog -Action "VALIDATION_FAILED" -User $env:USERNAME -Error ($criticalFailures | ConvertTo-Json)
    exit 1
}
```

## 🎯 **Mandatory AI Agent Guidelines**

### **CRITICAL: Security-First Development**
When rewriting or correcting scripts, AI agents MUST:

1. **🚫 ELIMINATE ALL HARDCODED VALUES**
   - Replace company names with generic parameters (`$OrganizationName`)
   - Replace server names with parameters (`$ServerName`, `$DatabaseServer`)
   - Replace domains with parameters (`$OrganizationDomain`)
   - Replace API keys/credentials with secure retrieval methods
   - Replace file paths with configurable parameters

2. **🔒 IMPLEMENT SECURITY PATTERNS**
   - Add comprehensive parameter validation
   - Implement secure credential handling
   - Add audit logging for all operations
   - Sanitize all output to prevent information disclosure
   - Add data classification handling

3. **📋 ENSURE COMPLIANCE**
   - Add required documentation headers
   - Implement WhatIf support for destructive operations
   - Add comprehensive error handling
   - Include regulatory compliance considerations
   - Document security impact and data handling

### **Example Transformation Pattern**
```powershell
# ❌ BEFORE: Hardcoded, insecure script
$server = "PROD-SQL-01.acmecorp.com"
$database = "UserData"
$user = "sa"
$password = "P@ssw0rd123"

Get-SqlData -Server $server -Database $database -User $user -Password $password

# ✅ AFTER: Parameterized, secure script
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true, HelpMessage="Database server hostname")]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseServer,

    [Parameter(Mandatory=$true, HelpMessage="Database name")]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory=$false, HelpMessage="Use Windows Authentication")]
    [switch]$UseWindowsAuth,

    [Parameter(Mandatory=$false, HelpMessage="Connection timeout in seconds")]
    [ValidateRange(5, 300)]
    [int]$TimeoutSeconds = 30
)

# Secure credential handling
if ($UseWindowsAuth) {
    $credentials = $null
} else {
    $credentials = Get-Credential -Message "Enter database credentials"
}

# Validation and execution with audit trail
if ($PSCmdlet.ShouldProcess($DatabaseServer, "Connect to Database")) {
    try {
        $result = Get-SqlData -Server $DatabaseServer -Database $DatabaseName -Credential $credentials -Timeout $TimeoutSeconds
        Write-AuditLog -Action "DATABASE_ACCESS_SUCCESS" -Target "$DatabaseServer\$DatabaseName" -User $env:USERNAME
        return $result
    } catch {
        $sanitizedError = $_.Exception.Message -replace $DatabaseServer, "[SERVER]"
        Write-Host "❌ Database connection failed: $sanitizedError" -ForegroundColor Red
        Write-AuditLog -Action "DATABASE_ACCESS_FAILED" -Target "$DatabaseServer\$DatabaseName" -User $env:USERNAME -Error $_.Exception.Message
        throw
    }
}
```

### **Contribution Requirements**
- **Security Review**: Every script must pass security compliance check
- **Testing**: Comprehensive Pester tests including security validation
- **Documentation**: Complete security and compliance documentation
- **Audit**: All changes must include audit trail implementation
- **Validation**: Parameter validation and input sanitization required

### **Deployment Standards**
- Code signing required for all production scripts
- Security scanning before deployment
- Compliance verification against organizational standards
- Change approval process for scripts handling sensitive data

### **Emergency Response**
- Immediate remediation process for security issues
- Incident response procedures for data exposure
- Rollback procedures for failed deployments
- Security incident documentation requirements

## 📞 **Contact & Governance**
- **Security Officer**: For security-related questions and approvals
- **Compliance Team**: For regulatory compliance verification
- **Repository Maintainer**: For technical questions and contributions
- **Change Advisory Board**: For production deployment approvals