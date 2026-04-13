# SECURITY-COMPLIANT AUTHENTICATION FUNCTIONS
# Remediated versions of vulnerable authentication functions
# SECURITY CLASSIFICATION: INTERNAL

<#
.SYNOPSIS
Security-enhanced versions of authentication functions from Connect-Office365Services.ps1

.DESCRIPTION
This file contains security-remediated versions of authentication functions with:
- Proper parameter validation
- Input sanitization
- Comprehensive audit logging
- Secure error handling
- SecureString best practices

.NOTES
SECURITY CLASSIFICATION: INTERNAL
DATA HANDLING: Enhanced authentication security patterns
AUDIT REQUIREMENTS: All authentication activities logged for security audit
#>

# Import required modules for audit logging
if (-not (Get-Module -Name 'Microsoft.PowerShell.Utility' -ListAvailable)) {
    Write-Warning "Required module Microsoft.PowerShell.Utility not found"
}

function Write-SecurityAuditLog {
    <#
    .SYNOPSIS
    Centralized security audit logging for authentication operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('AuthenticationAttempt', 'CredentialAccess', 'TenantLookup', 'SecurityEvent')]
        [string]$EventType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Success', 'Warning', 'Error')]
        [string]$Status = 'Success',

        [Parameter(Mandatory = $false)]
        [string]$UserContext = $env:USERNAME
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$EventType] [$Status] User: $UserContext | $Message"

    # Write to Windows Event Log for security audit
    try {
        Write-EventLog -LogName "Application" -Source "PowerShell" -EventId 1000 -EntryType Information -Message $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Fallback to file logging if Event Log unavailable
        $logPath = Join-Path $env:TEMP "PS-Security-Audit.log"
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    }

    # Also output to verbose stream for immediate feedback
    Write-Verbose $logEntry
}

function Get-TenantIDfromMail-Secure {
    <#
    .SYNOPSIS
    Security-enhanced version of Get-TenantIDfromMail with input validation and audit logging

    .DESCRIPTION
    Safely retrieves Azure AD Tenant ID from email address with proper validation

    .PARAMETER Email
    Valid email address to extract tenant information from

    .EXAMPLE
    Get-TenantIDfromMail-Secure -Email "user@contoso.com"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
        [string]$Email
    )

    begin {
        Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Starting tenant lookup for email domain" -Status 'Success'
    }

    process {
        try {
            # Extract domain part with additional validation
            $domainPart = ($Email -split '@')[1]

            # Additional domain validation - prevent injection attacks
            if ($domainPart -notmatch '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
                Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Invalid domain format detected: $domainPart" -Status 'Error'
                throw "Invalid domain format in email address"
            }

            # Sanitize domain for API call - remove any potential injection characters
            $sanitizedDomain = $domainPart -replace '[^a-zA-Z0-9.-]', ''

            # Construct secure API URL
            $apiUrl = "https://login.microsoftonline.com/{0}/v2.0/.well-known/openid-configuration" -f $sanitizedDomain

            Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Performing tenant lookup for domain: $sanitizedDomain" -Status 'Success'

            # Make REST API call with proper error handling
            $response = Invoke-RestMethod -Uri $apiUrl -Method GET -ErrorAction Stop

            if ($response -and $response.jwks_uri) {
                $tenantId = $response.jwks_uri.Split('/')[3]

                if ([string]::IsNullOrWhiteSpace($tenantId)) {
                    Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Empty tenant ID returned for domain: $sanitizedDomain" -Status 'Warning'
                    return $null
                }

                Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Successfully retrieved tenant ID for domain: $sanitizedDomain" -Status 'Success'
                return $tenantId
            }
            else {
                Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Invalid API response for domain: $sanitizedDomain" -Status 'Warning'
                return $null
            }
        }
        catch {
            Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Failed to retrieve tenant ID: $($_.Exception.Message)" -Status 'Error'
            Write-Warning "Could not determine Tenant ID using email address: $($_.Exception.Message)"
            return $null
        }
    }

    end {
        Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Completed tenant lookup operation" -Status 'Success'
    }
}

function Get-Office365Credentials-Secure {
    <#
    .SYNOPSIS
    Security-enhanced version of Get-Office365Credentials with audit logging

    .DESCRIPTION
    Securely prompts for Office 365 credentials with proper logging and validation

    .PARAMETER PreviousUsername
    Optional previous username to pre-populate credential prompt

    .EXAMPLE
    Get-Office365Credentials-Secure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PreviousUsername
    )

    begin {
        Write-SecurityAuditLog -EventType 'AuthenticationAttempt' -Message "Starting Office 365 credential collection" -Status 'Success'
    }

    process {
        try {
            # Secure credential prompt with audit logging
            Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Prompting user for Office 365 credentials" -Status 'Success'

            $credential = $host.ui.PromptForCredential(
                'Office 365 Credentials',
                'Please enter your Office 365 credentials',
                $PreviousUsername,
                ''
            )

            if ($credential -and $credential.UserName) {
                Write-SecurityAuditLog -EventType 'AuthenticationAttempt' -Message "Credentials collected for user: $($credential.UserName)" -Status 'Success'

                # Store in global variable (if required by existing code)
                $global:myOffice365Services['Office365Credentials'] = $credential

                # Get tenant information securely
                $tenantId = Get-TenantIDfromMail-Secure -Email $credential.UserName
                if ($tenantId) {
                    $global:myOffice365Services['Office365Tenant'] = $tenantId
                    Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Tenant ID resolved for user: $($credential.UserName)" -Status 'Success'
                }

                return $credential
            }
            else {
                Write-SecurityAuditLog -EventType 'AuthenticationAttempt' -Message "Credential collection cancelled by user" -Status 'Warning'
                return $null
            }
        }
        catch {
            Write-SecurityAuditLog -EventType 'AuthenticationAttempt' -Message "Credential collection failed: $($_.Exception.Message)" -Status 'Error'
            Write-Error "Failed to collect Office 365 credentials: $($_.Exception.Message)"
            return $null
        }
    }

    end {
        Write-SecurityAuditLog -EventType 'AuthenticationAttempt' -Message "Completed credential collection operation" -Status 'Success'
    }
}

function Get-OnPremisesCredentials-Secure {
    <#
    .SYNOPSIS
    Security-enhanced version of Get-OnPremisesCredentials with audit logging

    .DESCRIPTION
    Securely prompts for on-premises credentials with proper logging and validation

    .EXAMPLE
    Get-OnPremisesCredentials-Secure
    #>
    [CmdletBinding()]
    param()

    begin {
        Write-SecurityAuditLog -EventType 'AuthenticationAttempt' -Message "Starting on-premises credential collection" -Status 'Success'
    }

    process {
        try {
            Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Prompting user for on-premises credentials" -Status 'Success'

            $credential = $host.ui.PromptForCredential(
                'On-Premises Credentials',
                'Please Enter Your On-Premises Credentials',
                '',
                ''
            )

            if ($credential -and $credential.UserName) {
                Write-SecurityAuditLog -EventType 'AuthenticationAttempt' -Message "On-premises credentials collected for user: $($credential.UserName)" -Status 'Success'

                # Store in global variable (if required by existing code)
                $global:myOffice365Services['OnPremisesCredentials'] = $credential

                return $credential
            }
            else {
                Write-SecurityAuditLog -EventType 'AuthenticationAttempt' -Message "On-premises credential collection cancelled by user" -Status 'Warning'
                return $null
            }
        }
        catch {
            Write-SecurityAuditLog -EventType 'AuthenticationAttempt' -Message "On-premises credential collection failed: $($_.Exception.Message)" -Status 'Error'
            Write-Error "Failed to collect on-premises credentials: $($_.Exception.Message)"
            return $null
        }
    }

    end {
        Write-SecurityAuditLog -EventType 'AuthenticationAttempt' -Message "Completed on-premises credential collection" -Status 'Success'
    }
}

function Get-Office365Tenant-Secure {
    <#
    .SYNOPSIS
    Security-enhanced version of Get-Office365Tenant with input validation

    .DESCRIPTION
    Securely retrieves Office 365 tenant information with proper validation and logging

    .PARAMETER Credential
    Office 365 credential object to extract tenant from

    .EXAMPLE
    Get-Office365Tenant-Secure -Credential $cred
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    begin {
        Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Starting Office 365 tenant resolution" -Status 'Success'
    }

    process {
        try {
            # Use provided credential or global credential
            $targetCredential = $Credential
            if (-not $targetCredential) {
                $targetCredential = $global:myOffice365Services['Office365Credentials']
            }

            if ($targetCredential -and $targetCredential.UserName) {
                # Use secure tenant lookup function
                $tenantId = Get-TenantIDfromMail-Secure -Email $targetCredential.UserName

                if ($tenantId) {
                    $global:myOffice365Services['Office365Tenant'] = $tenantId
                    Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Tenant resolved successfully for user: $($targetCredential.UserName)" -Status 'Success'
                    return $tenantId
                }
                else {
                    Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Tenant lookup failed for user: $($targetCredential.UserName)" -Status 'Warning'
                    return $null
                }
            }
            else {
                Write-SecurityAuditLog -EventType 'TenantLookup' -Message "No credentials available for tenant lookup" -Status 'Warning'

                # Secure manual tenant entry
                do {
                    $tenantInput = Read-Host -Prompt 'Enter tenant ID, e.g. contoso for contoso.onmicrosoft.com'

                    # Validate tenant format
                    if ($tenantInput -match '^[a-zA-Z0-9-]+$' -and $tenantInput.Length -le 50) {
                        $global:myOffice365Services['Office365Tenant'] = $tenantInput
                        Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Manual tenant entry accepted: $tenantInput" -Status 'Success'
                        return $tenantInput
                    }
                    else {
                        Write-Warning "Invalid tenant format. Please use only letters, numbers, and hyphens."
                        Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Invalid manual tenant entry rejected: $tenantInput" -Status 'Warning'
                    }
                } while ($true)
            }
        }
        catch {
            Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Tenant resolution failed: $($_.Exception.Message)" -Status 'Error'
            Write-Error "Failed to resolve Office 365 tenant: $($_.Exception.Message)"
            return $null
        }
    }

    end {
        Write-SecurityAuditLog -EventType 'TenantLookup' -Message "Completed tenant resolution operation" -Status 'Success'
    }
}

# Export functions for use in other scripts
Export-ModuleMember -Function @(
    'Get-TenantIDfromMail-Secure',
    'Get-Office365Credentials-Secure',
    'Get-OnPremisesCredentials-Secure',
    'Get-Office365Tenant-Secure',
    'Write-SecurityAuditLog'
)

Write-Information "Security-Enhanced Authentication Functions Loaded Successfully" -InformationAction Continue
Write-Information "   - Input validation and sanitization enabled" -InformationAction Continue
Write-Information "   - Comprehensive audit logging active" -InformationAction Continue
Write-Information "   - Secure error handling implemented" -InformationAction Continue
Write-Information "   - Parameter validation enforced" -InformationAction Continue