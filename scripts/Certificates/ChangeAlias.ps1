#Requires -Version 5.1
<#
.SYNOPSIS
    Changes the alias of a certificate in a PFX file using OpenSSL or Keytool.

.DESCRIPTION
    This script imports a PFX certificate, extracts it to a temporary location, and changes
    the alias to a specified value using either OpenSSL or Java Keytool.

.PARAMETER PfxFilePath
    Path to the PFX certificate file.

.PARAMETER NewAlias
    The new alias name for the certificate.

.PARAMETER PfxPassword
    Password for the PFX file (if required).

.PARAMETER Tool
    Certificate tool to use: 'OpenSSL' or 'Keytool'. Defaults to 'OpenSSL'.

.PARAMETER OutputPath
    Output path for the modified PFX file. Defaults to same directory as input.

.EXAMPLE
    .\ChangeAlias.ps1 -PfxFilePath "C:\Certs\mycert.pfx" -NewAlias "production-cert" -Tool "OpenSSL"

.NOTES
    Requires OpenSSL or Java Keytool to be installed and available in system PATH.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(
        Mandatory=$true,
        Position=0,
        HelpMessage="Full path to the PFX certificate file"
    )]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$PfxFilePath,

    [Parameter(
        Mandatory=$true,
        Position=1,
        HelpMessage="New alias for the certificate (alphanumeric and hyphens only)"
    )]
    [ValidatePattern('^[a-zA-Z0-9\-]+$')]
    [ValidateNotNullOrEmpty()]
    [string]$NewAlias,

    [Parameter(Mandatory=$false, HelpMessage="Password for PFX file")]
    [securestring]$PfxPassword,

    [Parameter(
        Mandatory=$false,
        HelpMessage="Tool to use for alias change"
    )]
    [ValidateSet("OpenSSL", "Keytool")]
    [string]$Tool = "OpenSSL",

    [Parameter(Mandatory=$false, HelpMessage="Output directory for modified PFX")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$OutputPath = (Split-Path -Parent $PfxFilePath)
)

# Initialize session and logging
$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogFile = Join-Path $PSScriptRoot "ScriptAudit.log"

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory=$false)]
        [switch]$Sensitive
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $displayMessage = $Message
    
    # Sanitize sensitive paths in display output
    if ($displayMessage -like "*$env:USERNAME*") {
        $displayMessage = $displayMessage -replace [regex]::Escape($env:USERNAME), "[USER]"
    }

    $logEntry = "[$timestamp] [$script:SessionId] [$Level] $displayMessage"
    
    if (-not $Sensitive) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "AUDIT" { "Cyan" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    $fullLogEntry = "[$timestamp] [$script:SessionId] [$Level] [$env:USERNAME] $Message"
    Add-Content -Path $script:LogFile -Value $fullLogEntry -ErrorAction SilentlyContinue
}

function Test-ToolAvailability {
    param([string]$ToolName)
    
    Write-Log "Checking availability of $ToolName..." -Level "DEBUG"
    
    $tool = if ($ToolName -eq "OpenSSL") {
        Get-Command openssl.exe -ErrorAction SilentlyContinue
    } else {
        Get-Command keytool.exe -ErrorAction SilentlyContinue
    }
    
    if ($null -eq $tool) {
        Write-Log "❌ $ToolName not found in system PATH" -Level "ERROR"
        return $false
    }
    
    Write-Log "✅ $ToolName found" -Level "DEBUG"
    return $true
}

function Change-AliasOpenSSL {
    param(
        [string]$PfxPath,
        [securestring]$Password,
        [string]$Alias,
        [string]$OutputDir
    )
    
    $tempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "cert_$script:SessionId") -Force
    $keyFile = Join-Path $tempDir "key.pem"
    $certFile = Join-Path $tempDir "cert.pem"
    $outputPfx = Join-Path $OutputDir "$(Get-Item $PfxPath).BaseName)_$Alias.pfx"
    
    try {
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        )
        
        Write-Log "Extracting private key from PFX..." -Level "INFO"
        & openssl pkcs12 -in $PfxPath -nocerts -out $keyFile -password "pass:$plainPassword" -nodes 2>$null
        
        if (-not (Test-Path $keyFile)) {
            throw "Failed to extract private key"
        }
        
        Write-Log "Extracting certificate from PFX..." -Level "INFO"
        & openssl pkcs12 -in $PfxPath -nokeys -out $certFile -password "pass:$plainPassword" 2>$null
        
        if (-not (Test-Path $certFile)) {
            throw "Failed to extract certificate"
        }
        
        Write-Log "Creating new PFX with alias: $Alias" -Level "INFO"
        & openssl pkcs12 -export -in $certFile -inkey $keyFile -out $outputPfx `
            -name $Alias -password "pass:$plainPassword" 2>$null
        
        if (-not (Test-Path $outputPfx)) {
            throw "Failed to create output PFX"
        }
        
        Write-Log "✅ Certificate alias changed successfully" -Level "INFO"
        Write-Log "Output file: $outputPfx" -Level "INFO"
        Write-AuditLog -Action "ALIAS_CHANGED" -Target $outputPfx -User $env:USERNAME -AdditionalData @{Tool="OpenSSL"; NewAlias=$Alias}
        
        return $outputPfx
        
    } catch {
        Write-Log "❌ OpenSSL operation failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    } finally {
        $plainPassword = $null
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Change-AliasKeytool {
    param(
        [string]$PfxPath,
        [securestring]$Password,
        [string]$NewAlias,
        [string]$OutputDir
    )
    
    Write-Log "⚠️  Keytool requires JRE/JDK installation" -Level "WARNING"
    Write-Log "Keytool support not yet fully implemented. Use OpenSSL tool instead." -Level "ERROR"
    throw "Keytool implementation pending"
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
        [hashtable]$AdditionalData
    )

    $auditEntry = @{
        Timestamp = Get-Date -Format "o"
        SessionId = $script:SessionId
        Action = $Action
        User = $User
        Target = $Target
        ComputerName = $env:COMPUTERNAME
        ScriptName = $MyInvocation.ScriptName
        AdditionalData = $AdditionalData
    }

    $auditJson = $auditEntry | ConvertTo-Json -Compress
    Write-Log -Message $auditJson -Level "AUDIT" -Sensitive $true
}

# Main execution
Write-Log "🚀 Starting Certificate Alias Change Process" -Level "INFO"
Write-Log "Tool: $Tool | PFX: $(Split-Path -Leaf $PfxFilePath) | New Alias: $NewAlias" -Level "INFO"

if (-not (Test-ToolAvailability $Tool)) {
    Write-AuditLog -Action "TOOL_NOT_FOUND" -Target $Tool -User $env:USERNAME
    exit 1
}

if ($PSCmdlet.ShouldProcess($PfxFilePath, "Change certificate alias to '$NewAlias'")) {
    try {
        if ($Tool -eq "OpenSSL") {
            $result = Change-AliasOpenSSL -PfxPath $PfxFilePath -Password $PfxPassword `
                -Alias $NewAlias -OutputDir $OutputPath
        } else {
            $result = Change-AliasKeytool -PfxPath $PfxFilePath -Password $PfxPassword `
                -NewAlias $NewAlias -OutputDir $OutputPath
        }
        
        Write-Host "✅ Success: Certificate alias changed to '$NewAlias'" -ForegroundColor Green
        
    } catch {
        Write-AuditLog -Action "ALIAS_CHANGE_FAILED" -Target $PfxFilePath -User $env:USERNAME -AdditionalData @{Error=$_.Exception.Message}
        Write-Host "❌ Failed to change certificate alias" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "🔍 WhatIf: Would change alias of [$PfxFilePath] to [$NewAlias]" -ForegroundColor Yellow
}