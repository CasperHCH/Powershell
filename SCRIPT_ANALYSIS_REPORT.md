# PowerShell Script Analysis Report

**Generated:** October 9, 2025  
**Analysis Scope:** Active scripts in core/, autoload/, Tools/, PowerShell-Toolbox-master/, WindowsPowershell/, and docs/templates/  
**Excluded:** Archive folder (legacy/deprecated scripts)

## 🚨 **Critical Issues Found**

### **1. Incomplete Function Parameters - `connect-functions.ps1`**
**File:** `C:\PS\core\utilities\connect-functions.ps1`  
**Lines:** 35, 40  
**Severity:** ⚠️ **HIGH**

```powershell
# BROKEN: Missing required parameters
Function Connect-LyncPowershell {
    $CSSession = New-PSSession -Name  -ConnectionUri  -Credential (Get-Credential)  # ❌ Empty -Name and -ConnectionUri
    Import-PSSession $CSSession
}

Function Disconnect-LyncPowershell {
    Get-PSSession -Name  | Remove-PSSession  # ❌ Empty -Name parameter
}
```

**Impact:** These functions will fail at runtime due to missing parameter values.

**Recommended Fix:**
```powershell
Function Connect-LyncPowershell {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionUri,
        [Parameter(Mandatory = $true)]
        [string]$SessionName = "LyncRemoting"
    )
    $CSSession = New-PSSession -Name $SessionName -ConnectionUri $ConnectionUri -Credential (Get-Credential)
    Import-PSSession $CSSession
}

Function Disconnect-LyncPowershell {
    param(
        [string]$SessionName = "LyncRemoting"
    )
    Get-PSSession -Name $SessionName | Remove-PSSession
}
```

---

### **2. Hardcoded Server Names - Security & Portability Issues**
**Files:** Multiple locations  
**Severity:** ⚠️ **HIGH**

#### **`Get-AdSync.ps1` - Hardcoded Server**
**Line:** 6
```powershell
# ❌ HARDCODED: Server name should be configurable
Invoke-Command -ComputerName prod-adsync-01 -ScriptBlock { Get-ADSyncScheduler }
```

#### **`connect-functions.ps1` - Hardcoded Exchange Server**
**Line:** 5
```powershell
# ❌ HARDCODED: Exchange server should be configurable
$RPSession = New-PSSession -Name "ExchangeRemoting" -ConfigurationName Microsoft.Exchange -ConnectionURI http://BQ-MBX-02/Powershell
```

**Impact:** 
- Scripts won't work in different environments
- Security risk exposing internal server names
- Maintenance difficulty when servers change

**Recommended Fixes:**

**For Get-AdSync.ps1:**
```powershell
function Get-AdSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ComputerName = (Get-Content "$PSScriptRoot\..\config\adsync-server.txt" -ErrorAction SilentlyContinue),
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    if (-not $ComputerName) {
        $ComputerName = Read-Host "Enter AD Sync server name"
    }

    try {
        if ($Credential) {
            Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock { Get-ADSyncScheduler }
        } else {
            Invoke-Command -ComputerName $ComputerName -ScriptBlock { Get-ADSyncScheduler }
        }
    }
    catch {
        Write-Warning "Failed to connect to $ComputerName - $($_.Exception.Message)"
        Break
    }
}
```

**For connect-functions.ps1:**
```powershell
Function Connect-ExchPowershell {
    param(
        [Parameter(Mandatory = $false)]
        [string]$ExchangeServer = (Get-Content "$PSScriptRoot\..\config\exchange-server.txt" -ErrorAction SilentlyContinue),
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    if (-not $ExchangeServer) {
        $ExchangeServer = Read-Host "Enter Exchange server FQDN"
    }
    
    $ConnectionURI = "http://$ExchangeServer/Powershell"
    $RPSession = New-PSSession -Name "ExchangeRemoting" -ConfigurationName Microsoft.Exchange -ConnectionURI $ConnectionURI -Credential $Credential
    Import-PSSession $RPSession -Prefix local
    Write-Host "Connected to Exchange Server: $ExchangeServer" -ForegroundColor Green
}
```

---

### **3. Outdated Folder References - Path Issues**
**Files:** `WindowsPowershell\profile.ps1`, `WindowsPowershell\Microsoft.PowerShell_profile.ps1`  
**Severity:** ⚠️ **MEDIUM**

```powershell
# ❌ OUTDATED: References old Scripts folder that was reorganized
New-PSDrive -PSProvider FileSystem -Name "PS" -Root "C:\PS\Scripts" | Out-Null
Set-Location C:\PS\Scripts
```

**Impact:** Scripts will fail to find the expected directory structure.

**Recommended Fix:**
```powershell
# ✅ UPDATED: Reference new structure
New-PSDrive -PSProvider FileSystem -Name "PS" -Root "C:\PS" | Out-Null
Set-Location C:\PS

# Load from new core structure
$psdir = "C:\PS\core"
Get-ChildItem "$psdir\**\*.ps1" -Recurse | ForEach-Object { . $_ } | Out-Null
```

---

## 🔍 **Code Quality Issues**

### **4. Missing Error Handling - `AddTo-Path.ps1`**
**Severity:** ⚠️ **MEDIUM**

The script modifies registry without comprehensive error handling:

```powershell
# ❌ INCOMPLETE: No error handling for registry operations
Set-ItemProperty -Path $RegPropertyLocation -Name $PathType -Value $PathNew
```

**Recommended Fix:**
```powershell
try {
    Set-ItemProperty -Path $RegPropertyLocation -Name $PathType -Value $PathNew -ErrorAction Stop
    Write-Host "Successfully added $PathToAdd to $PathType" -ForegroundColor Green
} catch {
    Write-Error "Failed to update registry: $($_.Exception.Message)"
    return
}
```

### **5. Inconsistent Parameter Validation**
**Multiple Files**  
**Severity:** ⚠️ **LOW**

Some scripts lack proper parameter validation according to the development standards.

---

## 📊 **Security Assessment**

### **✅ Secure Credential Handling**
- ✅ No hardcoded passwords found in active scripts
- ✅ Proper use of `Get-Credential` and secure credential storage
- ✅ `Functions-PSStoredCredentials.ps1` implements secure patterns

### **✅ Modern PowerShell Practices**
- ✅ Most scripts use `[CmdletBinding()]`
- ✅ Proper parameter attributes in most cases
- ✅ Good use of `ValidateSet` and `ValidateNotNullOrEmpty`

---

## 🎯 **Recommendations**

### **Immediate Actions Required:**
1. **FIX CRITICAL:** Complete the missing parameters in `connect-functions.ps1`
2. **SECURITY:** Remove hardcoded server names and implement configuration files
3. **UPDATE PATHS:** Fix outdated folder references in profile scripts

### **Best Practice Improvements:**
1. **Standardize:** Apply consistent error handling patterns across all scripts
2. **Document:** Ensure all functions have complete help documentation
3. **Test:** Implement unit tests for core functions
4. **Config:** Create centralized configuration management for server names and settings

### **Suggested Configuration Structure:**
```
data/
├── config/
│   ├── servers.json          # Server configurations
│   ├── exchange-server.txt   # Exchange server FQDN
│   ├── adsync-server.txt     # AD Sync server name
│   └── environment.json      # Environment-specific settings
└── credentials/              # Secure credential storage
```

---

## 📈 **Overall Assessment**

**Status:** 🟡 **GOOD with Critical Issues**
- **Syntax Errors:** ✅ None found
- **Security Issues:** ✅ Clean (no credential exposure)
- **Functionality Issues:** ⚠️ 2 Critical, 3 Medium priority
- **Code Quality:** ✅ Generally follows best practices

**Next Steps:** Address the critical functionality issues, then implement the recommended improvements for better maintainability and security.