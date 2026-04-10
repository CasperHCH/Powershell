# PowerShell Security Development Standards

This guide outlines the **mandatory security standards** and coding practices for contributing to this enterprise PowerShell library.

## 🔐 **CRITICAL: Security-First Development Requirements**

### **Mandatory Security Checklist**
Every script MUST pass the following security requirements:
- [ ] **NO hardcoded credentials, API keys, or sensitive data**
- [ ] **NO company-specific names, domains, or identifiers**
- [ ] **ALL environment values converted to validated parameters**
- [ ] **Secure credential management implementation**
- [ ] **Audit logging for all sensitive operations**
- [ ] **Sanitized error messages (no information disclosure)**
- [ ] **Comprehensive input validation and parameter validation**
- [ ] **WhatIf support for all destructive operations**

## 📝 **Script Structure Standards**

### **Security-Enhanced Header Documentation**
Every script MUST include comprehensive security documentation:

```powershell
<#
.SYNOPSIS
    Brief one-line description of the script's purpose

.DESCRIPTION
    Detailed explanation of what the script does, how it works,
    and any important security considerations or data handling requirements

.PARAMETER OrganizationDomain
    Organization domain name (e.g., contoso.com)
    SECURITY: Generic parameter - no hardcoded company names

.PARAMETER ServerName
    Target server hostname or IP address
    SECURITY: Parameterized - no hardcoded server names

.PARAMETER UseStoredCredentials
    Use encrypted stored credentials instead of prompting
    SECURITY: Secure credential management option

.EXAMPLE
    ScriptName.ps1 -OrganizationDomain "contoso.com" -ServerName "server.contoso.com"

    Connects to specified server using secure credential prompt
    SECURITY: Uses generic example domain

.EXAMPLE
    ScriptName.ps1 -OrganizationDomain "contoso.com" -UseStoredCredentials -WhatIf

    Shows what actions would be performed without executing them
    SECURITY: Safe testing mode with stored credentials

.NOTES
    Author: [Your Name]
    Version: 1.0
    Dependencies: [List required modules]
    Last Modified: YYYY-MM-DD

    SECURITY CLASSIFICATION: [PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED]
    DATA HANDLING: [Describe types of data accessed/modified]
    AUDIT REQUIREMENTS: [SOX/GDPR/HIPAA compliance notes]
    CREDENTIALS REQUIRED: [Describe authentication needs]

.LINK
    Internal security documentation
    Relevant API documentation
#>
```

### **Parameter Declaration**
Use proper parameter attributes and validation:

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline = $true,
        HelpMessage = "Specify the user identifier"
    )]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Active", "Inactive", "Disabled")]
    [string]$Status = "Active",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$MaxResults = 100,

    [switch]$WhatIf,
    [switch]$Verbose
)
```

## 🔒 **Security Standards**

### **Never Hardcode Credentials**
❌ **NEVER DO THIS:**
```powershell
$username = "admin@company.com"
$password = "MySecretPassword123!"
```

✅ **DO THIS INSTEAD:**
```powershell
# Prompt for credentials
$credential = Get-Credential -Message "Enter your admin credentials"

# Or use secure storage
$credential = Import-Clixml -Path "$env:USERPROFILE\.credentials\admin.xml"

# For API tokens
$apiToken = Read-Host "Enter API Token" -AsSecureString
```

### **Secure Credential Storage**
```powershell
# Store credentials securely (one-time setup)
function Save-SecureCredential {
    param([string]$Name, [string]$Path = "$env:USERPROFILE\.credentials")

    if (-not (Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force }

    $credential = Get-Credential -Message "Enter credentials for $Name"
    $credential | Export-Clixml -Path "$Path\$Name.xml"
    Write-Host "Credentials saved securely to: $Path\$Name.xml" -ForegroundColor Green
}

# Load credentials (in scripts)
function Get-SecureCredential {
    param([string]$Name, [string]$Path = "$env:USERPROFILE\.credentials")

    $credPath = "$Path\$Name.xml"
    if (Test-Path $credPath) {
        return Import-Clixml -Path $credPath
    } else {
        throw "Credential file not found: $credPath. Run Save-SecureCredential first."
    }
}
```

## ⚠️ **Error Handling Standards**

### **Comprehensive Try-Catch Blocks**
```powershell
function Get-UserInformation {
    [CmdletBinding()]
    param([string]$Username)

    try {
        Write-Verbose "Attempting to retrieve user: $Username"

        # Main logic here
        $user = Get-ADUser -Identity $Username -ErrorAction Stop

        Write-Output $user
        Write-Host "Successfully retrieved user: $Username" -ForegroundColor Green
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Error "User '$Username' not found in Active Directory"
        return $null
    }
    catch [System.UnauthorizedAccessException] {
        Write-Error "Insufficient permissions to query Active Directory"
        return $null
    }
    catch {
        Write-Error "Unexpected error occurred: $($_.Exception.Message)"
        Write-Debug "Full exception: $($_.Exception | Out-String)"
        return $null
    }
}
```

### **Input Validation**
```powershell
# Validate email addresses
if ($Email -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
    throw "Invalid email address format: $Email"
}

# Validate file paths
if (-not (Test-Path $FilePath)) {
    throw "File not found: $FilePath"
}

# Validate against known values
$validEnvironments = @('Development', 'Testing', 'Production')
if ($Environment -notin $validEnvironments) {
    throw "Invalid environment. Valid options: $($validEnvironments -join ', ')"
}
```

## 🎨 **User Interface Standards**

### **Colorized Output**
```powershell
# Use consistent color coding
Write-Host "✅ Success: Operation completed successfully" -ForegroundColor Green
Write-Host "⚠️  Warning: Consider reviewing these settings" -ForegroundColor Yellow
Write-Host "❌ Error: Operation failed" -ForegroundColor Red
Write-Host "ℹ️  Info: Processing 50 items..." -ForegroundColor Cyan

# For progress indication
Write-Progress -Activity "Processing Users" -Status "User $i of $total" -PercentComplete (($i / $total) * 100)
```

### **Interactive Prompts**
```powershell
# Clear confirmation prompts
$confirmation = Read-Host "This will delete $($users.Count) users. Type 'YES' to confirm"
if ($confirmation -ne 'YES') {
    Write-Host "Operation cancelled by user" -ForegroundColor Yellow
    return
}

# Menu-based selection
do {
    Write-Host "`nSelect an option:" -ForegroundColor Cyan
    Write-Host "1. Process all users"
    Write-Host "2. Process specific group"
    Write-Host "3. Generate report only"
    Write-Host "Q. Quit"

    $choice = Read-Host "`nEnter your choice"
} while ($choice -notin @('1', '2', '3', 'Q'))
```

## 🔄 **API Integration Standards**

### **HTTP Request Patterns**
```powershell
function Invoke-ApiRequest {
    [CmdletBinding()]
    param(
        [string]$Uri,
        [hashtable]$Headers,
        [string]$Method = 'GET',
        [object]$Body,
        [int]$MaxRetries = 3
    )

    $retryCount = 0
    do {
        try {
            $params = @{
                Uri = $Uri
                Method = $Method
                Headers = $Headers
                ContentType = 'application/json'
            }

            if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 10) }

            $response = Invoke-RestMethod @params -ErrorAction Stop
            return $response
        }
        catch {
            $retryCount++
            if ($retryCount -ge $MaxRetries) {
                throw "API request failed after $MaxRetries attempts: $($_.Exception.Message)"
            }

            Write-Warning "API request failed (attempt $retryCount/$MaxRetries). Retrying in 5 seconds..."
            Start-Sleep -Seconds 5
        }
    } while ($retryCount -lt $MaxRetries)
}
```

### **Rate Limiting**
```powershell
# Implement rate limiting for API calls
$requestCount = 0
$startTime = Get-Date

foreach ($item in $items) {
    # Check rate limit (e.g., 100 requests per minute)
    if ($requestCount -ge 100) {
        $elapsed = (Get-Date) - $startTime
        if ($elapsed.TotalMinutes -lt 1) {
            $sleepTime = 60 - $elapsed.TotalSeconds
            Write-Host "Rate limit reached. Waiting $([math]::Round($sleepTime)) seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds $sleepTime
        }
        $requestCount = 0
        $startTime = Get-Date
    }

    # Make API call
    $result = Invoke-ApiRequest -Uri $uri
    $requestCount++
}
```

## 📊 **Logging and Reporting Standards**

### **Consistent Logging Pattern**
```powershell
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',

        [string]$LogPath = "$env:TEMP\PowerShell_$(Get-Date -Format 'yyyy-MM-dd').log"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to console with colors
    switch ($Level) {
        'INFO'    { Write-Host $logEntry -ForegroundColor White }
        'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logEntry -ForegroundColor Red }
        'DEBUG'   { Write-Debug $logEntry }
    }

    # Append to log file
    $logEntry | Add-Content -Path $LogPath
}
```

### **CSV Export Standards**
```powershell
# Always include metadata in exports
$results | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

# Add metadata header
$metadata = @"
# PowerShell Script Export
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Script: $($MyInvocation.MyCommand.Name)
# User: $($env:USERNAME)
# Computer: $($env:COMPUTERNAME)
# Total Records: $($results.Count)
"@

$metadata | Add-Content -Path $outputPath
```

## 🧪 **Testing Standards**

### **WhatIf Support**
```powershell
[CmdletBinding(SupportsShouldProcess)]
param(...)

if ($PSCmdlet.ShouldProcess($target, $operation)) {
    # Perform actual changes
    Remove-Item $filePath
    Write-Host "Deleted: $filePath" -ForegroundColor Green
} else {
    # WhatIf preview
    Write-Host "Would delete: $filePath" -ForegroundColor Yellow
}
```

### **Pester Tests**
When this repository contains an active test area for the script family you are working in, create or update corresponding Pester tests there. If no test area exists yet, document the missing coverage in your change notes rather than inventing a disconnected layout.

```powershell
# tests\unit-tests\Get-UserInformation.Tests.ps1
Describe "Get-UserInformation Tests" {
    BeforeAll {
        # Setup test data
        . "$PSScriptRoot\..\..\scripts\active-directory\Get-UserInformation.ps1"
    }

    Context "Parameter Validation" {
        It "Should throw when Username is empty" {
            { Get-UserInformation -Username "" } | Should -Throw
        }

        It "Should accept valid username" {
            { Get-UserInformation -Username "testuser" -WhatIf } | Should -Not -Throw
        }
    }

    Context "Functionality" {
        It "Should return user object when user exists" {
            # Mock AD cmdlets for testing
            Mock Get-ADUser { return @{Name = "Test User"} }

            $result = Get-UserInformation -Username "testuser"
            $result.Name | Should -Be "Test User"
        }
    }
}
```

## 📁 **File Organization Standards**

### **Script Placement**
- **Domain-specific scripts**: `scripts\[domain]\[category]\ScriptName.ps1`
- **Reusable functions**: `core\[category]\FunctionName.ps1`
- **Templates**: `docs\templates\`
- **Tests**: place under the repository's active test structure when one exists; otherwise note the gap and avoid creating an unrelated parallel convention

### **Naming Conventions**
- **Scripts**: `Verb-Noun.ps1` (e.g., `Get-MailboxPermissions.ps1`)
- **Functions**: `Verb-Noun` (e.g., `Get-UserInformation`)
- **Variables**: `$camelCase` (e.g., `$userAccount`, `$maxRetries`)
- **Constants**: `$UPPER_CASE` (e.g., `$API_BASE_URL`)

## 🔗 **Dependencies and Modules**

### **Module Loading**
```powershell
# Check and import required modules
$requiredModules = @('ActiveDirectory', 'ExchangeOnlineManagement', 'Microsoft.Graph')

foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        throw "Required module not found: $module. Please install using: Install-Module $module"
    }

    if (-not (Get-Module -Name $module)) {
        Import-Module $module -Force
        Write-Verbose "Imported module: $module"
    }
}
```

### **Version Compatibility**
```powershell
#Requires -Version 5.1
#Requires -Modules ActiveDirectory, ExchangeOnlineManagement

# Check PowerShell version for specific features
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "This script is optimized for PowerShell 7+. Some features may not work in Windows PowerShell 5.1"
}
```

---

Following these standards ensures consistency, security, and maintainability across the entire PowerShell library. All contributors should review and adhere to these guidelines.