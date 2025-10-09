# PowerShell Library Quick Start Guide

## 🚀 Getting Started

### Prerequisites
- **PowerShell 5.1** or **PowerShell 7+**
- **Execution Policy**: Set to `RemoteSigned` or `Unrestricted`
- **Git** (for cloning and version control)

### Initial Setup

1. **Clone the Repository**
```powershell
git clone https://github.com/CasperHCH/Powershell.git C:\PS
cd C:\PS
```

2. **Set Execution Policy** (if needed)
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

3. **Load PowerShell Profile**
The profile will automatically load core modules when you open PowerShell in the C:\PS directory.

## 📁 Navigating the Structure

### **Core Modules** (`core/`)
Essential functions loaded automatically:
- **Authentication**: `Connect-Office365Services.ps1`, `Test-ADCredential.ps1`
- **Utilities**: System monitoring, file operations, general helpers
- **Reporting**: Hardware specs, system reports

### **Scripts by Domain** (`scripts/`)
- **Exchange**: `scripts/exchange/` - Mailbox management, permissions
- **Active Directory**: `scripts/active-directory/` - User lifecycle, groups
- **Communication**: `scripts/communication/` - Teams, email automation
- **System Admin**: `scripts/system-administration/` - IIS, monitoring, security
- **Network**: `scripts/network/` - Connectivity testing, validation
- **Atlassian**: `scripts/atlassian/` - Jira, Confluence, OpsGenie

## 🔧 Common Tasks

### **Connect to Office 365**
```powershell
# Load authentication module (auto-loaded in profile)
Connect-ExchangeOnline
# Follow prompts for credentials
```

### **Active Directory Operations**
```powershell
# Find locked out users
. "C:\PS\scripts\active-directory\Get-LockedOutLocation.ps1"
Get-LockedOutLocation -Username "john.doe"

# Test AD credentials
. "C:\PS\core\authentication\Test-ADCredential.ps1"
Test-ADCredential -Username "domain\user" -Password "password"
```

### **Exchange Management**
```powershell
# Check mailbox automapping
. "C:\PS\scripts\exchange\Get-MailboxAutomapping.ps1"
Get-MailboxAutomapping -Mailbox "shared.mailbox@company.com"

# Get mailbox permissions
. "C:\PS\scripts\exchange\Get-MailboxPermissions.ps1"
Get-MailboxPermissions -Identity "user@company.com"
```

### **System Administration**
```powershell
# Check system uptime
. "C:\PS\core\utilities\Get-Uptime.ps1"
Get-Uptime

# Get hardware specifications
. "C:\PS\core\reporting\Get-ComputerHardwareSpecification.ps1"
Get-ComputerHardwareSpecification -ComputerName "SERVER01"
```

### **Atlassian Operations**
```powershell
# Disable Jira user (Cloud)
. "C:\PS\scripts\atlassian\cloud\DisableUser.ps1"
# Follow prompts for API token and user details

# Bulk operations
. "C:\PS\scripts\atlassian\cloud\Atlassian_Cloud_Delete_Users.ps1"
# Includes WhatIf support for safe testing
```

## 🛡️ Security Best Practices

### **Credential Management**
Never hardcode credentials. Use secure methods:

```powershell
# Store credentials securely
$cred = Get-Credential
$cred | Export-Clixml -Path "C:\PS\data\config\mycreds.xml"

# Load stored credentials
$cred = Import-Clixml -Path "C:\PS\data\config\mycreds.xml"
```

### **API Token Storage**
For API integrations:

```powershell
# Store API tokens securely
$apiToken = Read-Host "Enter API Token" -AsSecureString
$apiToken | ConvertFrom-SecureString | Out-File "C:\PS\data\config\api-token.txt"

# Load API tokens
$encToken = Get-Content "C:\PS\data\config\api-token.txt"
$secToken = ConvertTo-SecureString $encToken
$apiToken = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secToken))
```

## 📝 Creating New Scripts

### **Use the Template**
```powershell
# Copy template to your category
Copy-Item "C:\PS\docs\templates\Template.ps1" "C:\PS\scripts\[category]\MyNewScript.ps1"
```

### **Follow Naming Convention**
- Use PowerShell **Verb-Noun** format: `Get-UserData.ps1`, `Set-MailboxPermission.ps1`
- Place in appropriate domain folder
- Include comprehensive help documentation

### **Standard Script Structure**
```powershell
<#
.SYNOPSIS
    Brief description of what the script does
.DESCRIPTION
    Detailed description of functionality
.PARAMETER ParameterName
    Description of each parameter
.EXAMPLE
    Example usage with expected output
.NOTES
    Additional information, requirements, dependencies
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RequiredParameter,

    [Parameter(Mandatory=$false)]
    [switch]$OptionalSwitch
)

# Your script logic here
try {
    # Main functionality
    Write-Output "Script completed successfully"
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
}
```

## 🧪 Testing Your Scripts

### **Use WhatIf When Available**
```powershell
# Test without making changes
.\MyScript.ps1 -WhatIf
```

### **Validation Scripts**
```powershell
# Run validation tests
. "C:\PS\tests\validation-scripts\Test-ScriptSyntax.ps1"
Test-ScriptSyntax -Path "C:\PS\scripts\[category]\MyScript.ps1"
```

## 📚 Additional Resources

- **API Documentation**: `docs/api-references/` for complete API guides
- **Changelog**: `CHANGELOG.md` for version history and breaking changes
- **Copilot Instructions**: `copilot-instructions.md` for AI-assisted development
- **Examples**: Browse existing scripts in `scripts/` directories for patterns

## 🆘 Troubleshooting

### **Common Issues**
1. **Module Import Errors**: Ensure PowerShell profile loaded correctly
2. **Credential Issues**: Check secure storage and retrieval methods
3. **API Errors**: Verify tokens, endpoints, and network connectivity
4. **Path Issues**: Use absolute paths and verify folder structure

### **Getting Help**
- Review script help: `Get-Help .\ScriptName.ps1 -Full`
- Check examples: `Get-Help .\ScriptName.ps1 -Examples`
- Examine source: Scripts include comprehensive inline documentation

---

*For additional questions or contributions, refer to individual script documentation or repository maintainer.*