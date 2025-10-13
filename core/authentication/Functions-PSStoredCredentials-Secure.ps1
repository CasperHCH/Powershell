# SECURITY-ENHANCED STORED CREDENTIAL FUNCTIONS
# Remediated versions of Functions-PSStoredCredentials.ps1
# SECURITY CLASSIFICATION: INTERNAL

<#
.SYNOPSIS
Security-enhanced stored credential management functions

.DESCRIPTION
This file contains security-remediated versions of stored credential functions with:
- Comprehensive parameter validation
- Secure file path handling
- Enhanced audit logging
- Input sanitization and validation
- Improved error handling with secure messages

.NOTES
SECURITY CLASSIFICATION: INTERNAL
DATA HANDLING: Secure credential storage and retrieval
AUDIT REQUIREMENTS: All credential storage operations logged for security audit

Based on original work by Paul Cunningham with security enhancements
#>

# Import security audit logging function
. "$PSScriptRoot\Connect-Office365Services-Secure.ps1"

function New-StoredCredential-Secure {
    <#
    .SYNOPSIS
    Security-enhanced function to create new stored credentials

    .DESCRIPTION
    Securely stores credentials to encrypted .cred files with proper validation and audit logging

    .PARAMETER KeyPath
    Secure path where credential files will be stored (validated for security)

    .PARAMETER Username
    Optional username to pre-populate credential prompt (validated format)

    .PARAMETER Force
    Overwrite existing credential file if it exists

    .EXAMPLE
    New-StoredCredential-Secure -KeyPath "C:\SecureCredentials"

    .EXAMPLE
    New-StoredCredential-Secure -KeyPath "C:\SecureCredentials" -Username "admin@contoso.com"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateScript({
                if (-not (Test-Path $_ -IsValid)) {
                    throw "Invalid path format: $_"
                }
                # Ensure path is not in system directories for security
                $systemPaths = @($env:SystemRoot, $env:ProgramFiles, "${env:ProgramFiles(x86)}", $env:Windows)
                $resolvedPath = Resolve-Path $_ -ErrorAction SilentlyContinue
                foreach ($sysPath in $systemPaths) {
                    if ($resolvedPath -and $resolvedPath.Path.StartsWith($sysPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                        throw "Cannot store credentials in system directory: $_"
                    }
                }
                $true
            })]
        [string]$KeyPath,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$|^[a-zA-Z0-9\\._-]+$')]
        [string]$Username,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Starting new stored credential creation" -Status 'Success'
    }

    process {
        try {
            # Determine secure key path
            if (-not $PSBoundParameters.ContainsKey('KeyPath')) {
                if (Test-Path Variable:\KeyPath) {
                    $KeyPath = $global:KeyPath
                    Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Using existing global KeyPath: $KeyPath" -Status 'Success'
                }
                else {
                    Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "KeyPath variable not set, prompting user" -Status 'Warning'

                    do {
                        $path = Read-Host -Prompt "Enter a secure path for stored credentials (avoid system directories)"

                        # Validate path security
                        if (Test-Path $path -IsValid) {
                            $systemPaths = @($env:SystemRoot, $env:ProgramFiles, "${env:ProgramFiles(x86)}", $env:Windows)
                            $isSystemPath = $false
                            foreach ($sysPath in $systemPaths) {
                                if ($path.StartsWith($sysPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                                    $isSystemPath = $true
                                    break
                                }
                            }

                            if (-not $isSystemPath) {
                                Set-Variable -Name KeyPath -Scope Global -Value $path
                                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "KeyPath set to: $path" -Status 'Success'
                                break
                            }
                            else {
                                Write-Warning "System directories are not allowed for security. Please choose a different path."
                            }
                        }
                        else {
                            Write-Warning "Invalid path format. Please enter a valid directory path."
                        }
                    } while ($true)
                }
            }

            # Ensure directory exists with secure permissions
            if (-not (Test-Path $KeyPath)) {
                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Creating credential storage directory: $KeyPath" -Status 'Success'

                $directory = New-Item -ItemType Directory -Path $KeyPath -ErrorAction Stop

                # Set secure permissions (Windows only)
                if ($IsWindows -or ($PSVersionTable.PSVersion.Major -le 5)) {
                    try {
                        $acl = Get-Acl $directory.FullName
                        $acl.SetAccessRuleProtection($true, $false)  # Remove inheritance
                        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                            "FullControl",
                            "Allow"
                        )
                        $acl.SetAccessRule($accessRule)
                        Set-Acl $directory.FullName $acl
                        Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Secure permissions set on credential directory" -Status 'Success'
                    }
                    catch {
                        Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Warning: Could not set secure permissions: $($_.Exception.Message)" -Status 'Warning'
                    }
                }
            }

            # Get credentials securely
            Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Prompting for credential information" -Status 'Success'

            $promptMessage = "Enter credentials for secure storage"
            $credential = Get-Credential -Message $promptMessage -UserName $Username

            if (-not $credential) {
                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Credential creation cancelled by user" -Status 'Warning'
                return
            }

            # Validate username format
            if ($credential.Username -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$|^[a-zA-Z0-9\\._-]+$') {
                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Invalid username format provided: $($credential.Username)" -Status 'Error'
                throw "Invalid username format. Please use email format or valid domain\\username format."
            }

            # Sanitize filename - remove invalid characters
            $sanitizedUsername = $credential.Username -replace '[<>:"/\\|?*]', '_'
            $credentialPath = Join-Path $KeyPath "$sanitizedUsername.cred"

            # Check if credential already exists
            if ((Test-Path $credentialPath) -and (-not $Force)) {
                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Credential file already exists for user: $($credential.Username)" -Status 'Warning'

                $overwrite = Read-Host "Credential file already exists for $($credential.Username). Overwrite? (y/N)"
                if ($overwrite -notlike 'y*') {
                    Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Credential storage cancelled - file exists" -Status 'Warning'
                    return
                }
            }

            # Store credential securely
            if ($PSCmdlet.ShouldProcess($credentialPath, "Store encrypted credential")) {
                $credential.Password | ConvertFrom-SecureString | Out-File $credentialPath -Force -ErrorAction Stop

                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Credential successfully stored for user: $($credential.Username)" -Status 'Success'
                Write-Host "✅ Credential stored successfully for: $($credential.Username)" -ForegroundColor Green

                # Set file permissions (Windows only)
                if ($IsWindows -or ($PSVersionTable.PSVersion.Major -le 5)) {
                    try {
                        $acl = Get-Acl $credentialPath
                        $acl.SetAccessRuleProtection($true, $false)  # Remove inheritance
                        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                            "FullControl",
                            "Allow"
                        )
                        $acl.SetAccessRule($accessRule)
                        Set-Acl $credentialPath $acl
                    }
                    catch {
                        Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Warning: Could not set secure file permissions" -Status 'Warning'
                    }
                }
            }
        }
        catch {
            Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Failed to create stored credential: $($_.Exception.Message)" -Status 'Error'
            Write-Error "Failed to create stored credential: $($_.Exception.Message)"
        }
    }

    end {
        Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Completed stored credential creation operation" -Status 'Success'
    }
}

function Get-StoredCredential-Secure {
    <#
    .SYNOPSIS
    Security-enhanced function to retrieve stored credentials

    .DESCRIPTION
    Securely retrieves stored credentials with proper validation and audit logging

    .PARAMETER UserName
    Username of the stored credential to retrieve (validated format)

    .PARAMETER List
    List all available stored credentials

    .PARAMETER KeyPath
    Path where credential files are stored (validated for security)

    .EXAMPLE
    Get-StoredCredential-Secure -List

    .EXAMPLE
    $cred = Get-StoredCredential-Secure -UserName "admin@contoso.com"

    .EXAMPLE
    Get-StoredCredential-Secure -UserName "domain\admin" -KeyPath "C:\SecureCredentials"
    #>
    [CmdletBinding(DefaultParameterSetName = "List")]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "Get")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$|^[a-zA-Z0-9\\._-]+$')]
        [string]$UserName,

        [Parameter(Mandatory = $false, ParameterSetName = "List")]
        [switch]$List,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
                if (-not (Test-Path $_ -PathType Container -ErrorAction SilentlyContinue)) {
                    throw "KeyPath directory does not exist: $_"
                }
                $true
            })]
        [string]$KeyPath
    )

    begin {
        Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Starting stored credential retrieval" -Status 'Success'
    }

    process {
        try {
            # Determine key path
            if (-not $PSBoundParameters.ContainsKey('KeyPath')) {
                if (Test-Path Variable:\KeyPath) {
                    $KeyPath = $global:KeyPath
                }
                else {
                    Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "KeyPath not set, prompting user" -Status 'Warning'
                    $path = Read-Host -Prompt "Enter the path where credentials are stored"

                    if (-not (Test-Path $path -PathType Container)) {
                        Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Invalid KeyPath provided: $path" -Status 'Error'
                        throw "Directory does not exist: $path"
                    }

                    Set-Variable -Name KeyPath -Scope Global -Value $path
                    Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "KeyPath set to: $path" -Status 'Success'
                }
            }

            if ($List) {
                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Listing stored credentials in: $KeyPath" -Status 'Success'

                $credentialList = @(Get-ChildItem -Path $KeyPath -Filter "*.cred" -ErrorAction Stop)

                if ($credentialList.Count -eq 0) {
                    Write-Host "No stored credentials found in: $KeyPath" -ForegroundColor Yellow
                    Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "No stored credentials found" -Status 'Success'
                }
                else {
                    Write-Host "📋 Stored Credentials in: $KeyPath" -ForegroundColor Green
                    Write-Host "=" * 50

                    foreach ($cred in $credentialList) {
                        $username = $cred.BaseName
                        $lastModified = $cred.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                        Write-Host "Username: $username | Last Modified: $lastModified" -ForegroundColor Cyan
                    }

                    Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Listed $($credentialList.Count) stored credentials" -Status 'Success'
                }
            }

            if ($PSBoundParameters.ContainsKey('UserName')) {
                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Retrieving stored credential for user: $UserName" -Status 'Success'

                # Sanitize filename - same as storage
                $sanitizedUsername = $UserName -replace '[<>:"/\\|?*]', '_'
                $credentialPath = Join-Path $KeyPath "$sanitizedUsername.cred"

                if (-not (Test-Path $credentialPath)) {
                    Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Stored credential not found for user: $UserName" -Status 'Warning'
                    throw "Unable to locate a stored credential for: $UserName"
                }

                # Retrieve and decrypt credential
                $encryptedPassword = Get-Content $credentialPath -ErrorAction Stop
                $securePassword = $encryptedPassword | ConvertTo-SecureString -ErrorAction Stop

                $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $securePassword

                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Successfully retrieved stored credential for user: $UserName" -Status 'Success'
                Write-Verbose "✅ Retrieved stored credential for: $UserName"

                return $credential
            }
        }
        catch [System.Security.Cryptography.CryptographicException] {
            Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Credential decryption failed - may have been encrypted by different user/machine" -Status 'Error'
            Write-Error "Cannot decrypt stored credential. Credential may have been encrypted by a different user or on a different machine."
        }
        catch {
            Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Failed to retrieve stored credential: $($_.Exception.Message)" -Status 'Error'
            Write-Error "Failed to retrieve stored credential: $($_.Exception.Message)"
        }
    }

    end {
        Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Completed stored credential retrieval operation" -Status 'Success'
    }
}

function Remove-StoredCredential-Secure {
    <#
    .SYNOPSIS
    Security-enhanced function to remove stored credentials

    .DESCRIPTION
    Securely removes stored credential files with proper validation and audit logging

    .PARAMETER UserName
    Username of the stored credential to remove

    .PARAMETER KeyPath
    Path where credential files are stored

    .PARAMETER Force
    Remove without confirmation prompt

    .EXAMPLE
    Remove-StoredCredential-Secure -UserName "admin@contoso.com"

    .EXAMPLE
    Remove-StoredCredential-Secure -UserName "testuser" -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$|^[a-zA-Z0-9\\._-]+$')]
        [string]$UserName,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
                if (-not (Test-Path $_ -PathType Container -ErrorAction SilentlyContinue)) {
                    throw "KeyPath directory does not exist: $_"
                }
                $true
            })]
        [string]$KeyPath,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Starting stored credential removal for user: $UserName" -Status 'Success'
    }

    process {
        try {
            # Determine key path
            if (-not $PSBoundParameters.ContainsKey('KeyPath')) {
                if (Test-Path Variable:\KeyPath) {
                    $KeyPath = $global:KeyPath
                }
                else {
                    throw "KeyPath not specified and global KeyPath variable not set"
                }
            }

            # Sanitize filename
            $sanitizedUsername = $UserName -replace '[<>:"/\\|?*]', '_'
            $credentialPath = Join-Path $KeyPath "$sanitizedUsername.cred"

            if (-not (Test-Path $credentialPath)) {
                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Stored credential not found for removal: $UserName" -Status 'Warning'
                Write-Warning "No stored credential found for: $UserName"
                return
            }

            if ($PSCmdlet.ShouldProcess($credentialPath, "Remove stored credential")) {
                Remove-Item $credentialPath -Force -ErrorAction Stop
                Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Successfully removed stored credential for user: $UserName" -Status 'Success'
                Write-Host "✅ Removed stored credential for: $UserName" -ForegroundColor Green
            }
        }
        catch {
            Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Failed to remove stored credential: $($_.Exception.Message)" -Status 'Error'
            Write-Error "Failed to remove stored credential: $($_.Exception.Message)"
        }
    }

    end {
        Write-SecurityAuditLog -EventType 'CredentialAccess' -Message "Completed stored credential removal operation" -Status 'Success'
    }
}

# Export functions for use in other scripts
Export-ModuleMember -Function @(
    'New-StoredCredential-Secure',
    'Get-StoredCredential-Secure',
    'Remove-StoredCredential-Secure'
)

Write-Host "🔒 Security-Enhanced Stored Credential Functions Loaded Successfully" -ForegroundColor Green
Write-Host "   - Comprehensive parameter validation enabled" -ForegroundColor Green
Write-Host "   - Secure file path handling implemented" -ForegroundColor Green
Write-Host "   - Enhanced audit logging active" -ForegroundColor Green
Write-Host "   - Input sanitization and validation enforced" -ForegroundColor Green
Write-Host "   - Secure file permissions applied" -ForegroundColor Green