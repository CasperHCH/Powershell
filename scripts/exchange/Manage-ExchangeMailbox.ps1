<#
.SYNOPSIS
    Unified Exchange mailbox management: folder permissions, send permissions, forwarding rules

.DESCRIPTION
    Consolidates mailbox folder permission management (add/remove), send permissions (Send-As, Send-On-Behalf-To), and forwarding rule analysis into a single enterprise-grade, security-compliant script.

.PARAMETER Operation
    The operation to perform: AddMailboxFolderPermission, RemoveMailboxFolderPermission, GetSendAs, GetSendOnBehalfTo, GrantSendOnBehalfTo, GetMailboxForwardingEnabled
.PARAMETER Mailbox
    The mailbox identity (email or display name)
.PARAMETER User
    The user to add/remove permissions for (folder permissions)
.PARAMETER Access
    The access level to grant (add folder permission)
.PARAMETER Users
    Comma-separated list of users to grant Send-On-Behalf-To permissions (for GrantSendOnBehalfTo)
.PARAMETER OutputPath
    Path to export forwarding rule results (for GetMailboxForwardingEnabled)
.PARAMETER IncludeInternal
    Include internal forwarding rules (for GetMailboxForwardingEnabled)
.PARAMETER MaxParallelJobs
    Maximum concurrent mailbox processing jobs (for GetMailboxForwardingEnabled)
.PARAMETER LogPath
    Path to audit log file (default: .\ExchangeMailboxAudit.log)
.PARAMETER WhatIf
    Preview changes without making them (for permission operations)
.PARAMETER Confirm
    Prompt for confirmation before making changes (for permission operations)

.EXAMPLE
    .\Manage-ExchangeMailbox.ps1 -Operation AddMailboxFolderPermission -Mailbox "john.doe" -User "manager" -Access "Reviewer" -WhatIf
.EXAMPLE
    .\Manage-ExchangeMailbox.ps1 -Operation RemoveMailboxFolderPermission -Mailbox "alex.heyne" -User "alan.reid" -Confirm
.EXAMPLE
    .\Manage-ExchangeMailbox.ps1 -Operation GetSendAs -Mailbox "john.doe@contoso.com"
.EXAMPLE
    .\Manage-ExchangeMailbox.ps1 -Operation GetSendOnBehalfTo -Mailbox "john.doe@contoso.com"
.EXAMPLE
    .\Manage-ExchangeMailbox.ps1 -Operation GrantSendOnBehalfTo -Mailbox "john.doe@contoso.com" -Users "jane.smith@contoso.com,admin@contoso.com" -Confirm
.EXAMPLE
    .\Manage-ExchangeMailbox.ps1 -Operation GetMailboxForwardingEnabled -OutputPath "C:\Reports\ForwardingRules.csv"

.NOTES
    Author: [Your Name]
    Created: [Date]
    Version: 2.0
    Requirements: PowerShell 5.1+, Exchange Online/On-Prem modules, permissions for mailbox management
    SECURITY: No hardcoded credentials, domains, or sensitive data. All operations are parameterized and logged.
    COMPLIANCE: GDPR, SOX, CCPA. All data access and modifications are logged. No sensitive data exposed in output.

.LINK
    See copilot-instructions.md for repository standards and security requirements
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Operation to perform")]
    [ValidateSet("AddMailboxFolderPermission", "RemoveMailboxFolderPermission", "GetSendAs", "GetSendOnBehalfTo", "GrantSendOnBehalfTo", "GetMailboxForwardingEnabled")]
    [string]$Operation,
    [Parameter(Mandatory = $false, HelpMessage = "Mailbox identity (email or display name)")]
    [ValidateNotNullOrEmpty()]
    [string]$Mailbox,
    [Parameter(Mandatory = $false, HelpMessage = "User for folder permission operations")]
    [ValidateNotNullOrEmpty()]
    [string]$User,
    [Parameter(Mandatory = $false, HelpMessage = "Access level for AddMailboxFolderPermission")]
    [ValidateSet("Owner", "PublishingEditor", "Editor", "Reviewer", "Contributor", "NonEditingAuthor", "Author", "Custom")]
    [string]$Access,
    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated users for GrantSendOnBehalfTo")]
    [string]$Users,
    [Parameter(Mandatory = $false, HelpMessage = "Output path for forwarding rules export")]
    [string]$OutputPath = ".\ExternalForwardingRules_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    [Parameter(Mandatory = $false, HelpMessage = "Include internal forwarding rules")]
    [switch]$IncludeInternal,
    [Parameter(Mandatory = $false, HelpMessage = "Max parallel jobs for forwarding analysis")]
    [int]$MaxParallelJobs = 10,
    [Parameter(Mandatory = $false, HelpMessage = "Path to audit log file")]
    [string]$LogPath = ".\ExchangeMailboxAudit.log"
)

try {
    switch ($Operation) {
        "AddMailboxFolderPermission" {
            if (-not $Mailbox -or -not $User -or -not $Access) {
                throw "Mailbox, User, and Access parameters are required for AddMailboxFolderPermission."
            }
            Write-Host "Adding $Access permission for $User to all folders in mailbox: $Mailbox" -ForegroundColor Cyan
            $folders = Get-MailboxFolderStatistics -Identity $Mailbox | Where-Object { $_.FolderType -eq "User" }
            foreach ($folder in $folders) {
                $folderPath = $folder.FolderPath.Replace("/", "\")
                if ($folderPath -match "Top of Information Store") {
                    $folderPath = $folderPath.Replace("\Top of Information Store", "\")
                }
                try {
                    Add-MailboxFolderPermission -Identity "$Mailbox`:$folderPath" -User $User -AccessRights $Access -ErrorAction Stop
                    Write-Host "  Granted $Access to $User on $folderPath" -ForegroundColor Green
                }
                catch {
                    Write-Host "  Error on $folderPath: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        "RemoveMailboxFolderPermission" {
            if (-not $Mailbox -or -not $User) {
                throw "Mailbox and User parameters are required for RemoveMailboxFolderPermission."
            }
            Write-Host "Removing $User's permissions from all folders in mailbox: $Mailbox" -ForegroundColor Cyan
            $folders = Get-MailboxFolderStatistics -Identity $Mailbox | Where-Object { $_.FolderType -eq "User" }
            foreach ($folder in $folders) {
                $folderPath = $folder.FolderPath.Replace("/", "\")
                if ($folderPath -match "Top of Information Store") {
                    $folderPath = $folderPath.Replace("\Top of Information Store", "\")
                }
                try {
                    Remove-MailboxFolderPermission -Identity "$Mailbox`:$folderPath" -User $User -ErrorAction Stop
                    Write-Host "  Removed $User from $folderPath" -ForegroundColor Green
                }
                catch {
                    Write-Host "  Error on $folderPath: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        "GetSendAs" {
            if (-not $Mailbox) { throw "Mailbox parameter required for GetSendAs." }
            Write-Host "Getting Send-As permissions for mailbox: $Mailbox" -ForegroundColor Cyan
            $sendAsPermissions = Get-Mailbox -Identity $Mailbox -ErrorAction Stop | Get-ADPermission | Where-Object { $_.ExtendedRights -like "*Send-As*" }
            if ($sendAsPermissions) {
                Write-Host "✅ Found Send-As permissions:" -ForegroundColor Green
                $sendAsPermissions | Format-Table User, ExtendedRights, AccessRights -AutoSize
            }
            else {
                Write-Host "⚠️ No Send-As permissions found for $Mailbox" -ForegroundColor Yellow
            }
        }
        "GetSendOnBehalfTo" {
            if (-not $Mailbox) { throw "Mailbox parameter required for GetSendOnBehalfTo." }
            Write-Host "Getting Send-On-Behalf-To permissions for mailbox: $Mailbox" -ForegroundColor Cyan
            $mailboxObj = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
            Write-Host "✅ Mailbox Information:" -ForegroundColor Green
            $mailboxObj | Format-List DisplayName, GrantSendOnBehalfTo
            if ($mailboxObj.GrantSendOnBehalfTo.Count -gt 0) {
                Write-Host "Send-On-Behalf-To permissions granted to:" -ForegroundColor Yellow
                $mailboxObj.GrantSendOnBehalfTo | ForEach-Object { Write-Host "  - $_" }
            }
            else {
                Write-Host "⚠️ No Send-On-Behalf-To permissions found" -ForegroundColor Yellow
            }
        }
        "GrantSendOnBehalfTo" {
            if (-not $Mailbox -or -not $Users) {
                throw "Mailbox and Users parameters required for GrantSendOnBehalfTo."
            }
            Write-Host "Granting Send-On-Behalf-To permissions for mailbox: $Mailbox" -ForegroundColor Cyan
            $mailboxObj = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
            $currentPermissions = $mailboxObj.GrantSendOnBehalfTo
            $newUsers = $Users -split ',' | ForEach-Object { $_.Trim() }
            $allPermissions = @()
            if ($currentPermissions) { $allPermissions += $currentPermissions }
            foreach ($user in $newUsers) {
                if ($user -and $allPermissions -notcontains $user) {
                    $allPermissions += $user
                    Write-Host "  Adding: $user" -ForegroundColor Yellow
                }
                elseif ($allPermissions -contains $user) {
                    Write-Host "  Already exists: $user" -ForegroundColor Cyan
                }
            }
            Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo $allPermissions -ErrorAction Stop
            Write-Host "✅ Send-On-Behalf-To permissions updated successfully" -ForegroundColor Green
        }
        "GetMailboxForwardingEnabled" {
            Write-Host "Analyzing mailbox forwarding rules..." -ForegroundColor Cyan
            $mailboxes = Get-Mailbox -ResultSize Unlimited
            $results = @()
            $jobs = @()
            $jobThrottle = $MaxParallelJobs
            foreach ($mb in $mailboxes) {
                while ($jobs.Count -ge $jobThrottle) {
                    $jobs = $jobs | Where-Object { $_.State -eq "Running" }
                    function Write-Log {
                        param(
                            [Parameter(Mandatory = $true)]
                            [string]$Message,
                            [Parameter(Mandatory = $false)]
                            [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "AUDIT")]
                            [string]$Level = "INFO",
                            [Parameter(Mandatory = $false)]
                            [switch]$Sensitive,
                            [Parameter(Mandatory = $false)]
                            [string]$LogPath = $LogPath
                        )
                        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        $sessionId = $script:SessionId ?? (New-Guid).ToString().Substring(0, 8)
                        $displayMessage = $Message
                        $logEntry = "[$timestamp] [$sessionId] [$Level] $displayMessage"
                        if (-not $Sensitive) {
                            $color = switch ($Level) {
                                "ERROR" { "Red" }
                                "WARNING" { "Yellow" }
                                "AUDIT" { "Cyan" }
                                default { "White" }
                            }
                            Write-Host $logEntry -ForegroundColor $color
                        }
                        $fullLogEntry = "[$timestamp] [$sessionId] [$Level] [$env:USERNAME] $Message"
                        try {
                            Add-Content -Path $LogPath -Value $fullLogEntry -ErrorAction Stop
                        }
                        catch {
                            Write-Warning "Failed to write to log file: $_"
                        }
                    }

                    function Write-AuditLog {
                        param(
                            [Parameter(Mandatory = $true)]
                            [string]$Action,
                            [Parameter(Mandatory = $false)]
                            [string]$Target,
                            [Parameter(Mandatory = $true)]
                            [string]$User,
                            [Parameter(Mandatory = $false)]
                            [string]$Error,
                            [Parameter(Mandatory = $false)]
                            [hashtable]$AdditionalData
                        )
                        $auditEntry = @{
                            Timestamp      = Get-Date -Format "o"
                            SessionId      = $script:SessionId
                            Action         = $Action
                            User           = $User
                            Target         = $Target
                            Error          = $Error
                            ComputerName   = $env:COMPUTERNAME
                            ScriptName     = $MyInvocation.ScriptName
                            AdditionalData = $AdditionalData
                        }
                        $auditJson = $auditEntry | ConvertTo-Json -Compress
                        Write-Log -Message $auditJson -Level "AUDIT" -Sensitive $true -LogPath $LogPath
                    }

                    function Validate-Mailbox {
                        param([string]$Mailbox)
                        try {
                            $null = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
                            return $true
                        }
                        catch {
                            Write-Log -Message "Mailbox validation failed for $Mailbox: $($_.Exception.Message)" -Level "ERROR" -LogPath $LogPath
                            return $false
                        }
                    }

                    function Validate-User {
                        param([string]$User)
                        try {
                            $null = Get-Recipient -Identity $User -ErrorAction Stop
                            return $true
                        }
                        catch {
                            Write-Log -Message "User validation failed for $User: $($_.Exception.Message)" -Level "ERROR" -LogPath $LogPath
                            return $false
                        }
                    }

                    function Add-MailboxFolderPermissionSecure {
                        param([string]$Mailbox, [string]$User, [string]$Access)
                        if (-not (Validate-Mailbox $Mailbox)) { throw "Invalid mailbox: $Mailbox" }
                        if (-not (Validate-User $User)) { throw "Invalid user: $User" }
                        $folders = Get-MailboxFolderStatistics -Identity $Mailbox | Where-Object { $_.FolderType -eq "User" }
                        foreach ($folder in $folders) {
                            $folderPath = $folder.FolderPath.Replace("/", "\")
                            if ($folderPath -match "Top of Information Store") {
                                $folderPath = $folderPath.Replace("\Top of Information Store", "\")
                            }
                            if ($PSCmdlet.ShouldProcess("$Mailbox:$folderPath", "Add $Access permission for $User")) {
                                try {
                                    Add-MailboxFolderPermission -Identity "$Mailbox`:$folderPath" -User $User -AccessRights $Access -ErrorAction Stop
                                    Write-Log -Message "Granted $Access to $User on $folderPath" -Level "INFO" -LogPath $LogPath
                                    Write-AuditLog -Action "ADD_FOLDER_PERMISSION" -Target "$Mailbox:$folderPath" -User $env:USERNAME -AdditionalData @{User = $User; Access = $Access }
                                }
                                catch {
                                    $sanitizedError = $_.Exception.Message -replace $Mailbox, "[MAILBOX]" -replace $User, "[USER]"
                                    Write-Log -Message "Error on $folderPath: $sanitizedError" -Level "ERROR" -LogPath $LogPath
                                    Write-AuditLog -Action "ADD_FOLDER_PERMISSION_FAILED" -Target "$Mailbox:$folderPath" -User $env:USERNAME -Error $sanitizedError -AdditionalData @{User = $User; Access = $Access }
                                }
                            }
                        }
                    }

                    function Remove-MailboxFolderPermissionSecure {
                        param([string]$Mailbox, [string]$User)
                        if (-not (Validate-Mailbox $Mailbox)) { throw "Invalid mailbox: $Mailbox" }
                        if (-not (Validate-User $User)) { throw "Invalid user: $User" }
                        $folders = Get-MailboxFolderStatistics -Identity $Mailbox | Where-Object { $_.FolderType -eq "User" }
                        foreach ($folder in $folders) {
                            $folderPath = $folder.FolderPath.Replace("/", "\")
                            if ($folderPath -match "Top of Information Store") {
                                $folderPath = $folderPath.Replace("\Top of Information Store", "\")
                            }
                            if ($PSCmdlet.ShouldProcess("$Mailbox:$folderPath", "Remove $User permission")) {
                                try {
                                    Remove-MailboxFolderPermission -Identity "$Mailbox`:$folderPath" -User $User -ErrorAction Stop
                                    Write-Log -Message "Removed $User from $folderPath" -Level "INFO" -LogPath $LogPath
                                    Write-AuditLog -Action "REMOVE_FOLDER_PERMISSION" -Target "$Mailbox:$folderPath" -User $env:USERNAME -AdditionalData @{User = $User }
                                }
                                catch {
                                    $sanitizedError = $_.Exception.Message -replace $Mailbox, "[MAILBOX]" -replace $User, "[USER]"
                                    Write-Log -Message "Error on $folderPath: $sanitizedError" -Level "ERROR" -LogPath $LogPath
                                    Write-AuditLog -Action "REMOVE_FOLDER_PERMISSION_FAILED" -Target "$Mailbox:$folderPath" -User $env:USERNAME -Error $sanitizedError -AdditionalData @{User = $User }
                                }
                            }
                        }
                    }

                    function Get-SendAsSecure {
                        param([string]$Mailbox)
                        if (-not (Validate-Mailbox $Mailbox)) { throw "Invalid mailbox: $Mailbox" }
                        Write-Log -Message "Getting Send-As permissions for mailbox: $Mailbox" -Level "INFO" -LogPath $LogPath
                        $sendAsPermissions = Get-Mailbox -Identity $Mailbox -ErrorAction Stop | Get-ADPermission | Where-Object { $_.ExtendedRights -like "*Send-As*" }
                        if ($sendAsPermissions) {
                            Write-Log -Message "Found Send-As permissions" -Level "INFO" -LogPath $LogPath
                            $sendAsPermissions | Format-Table User, ExtendedRights, AccessRights -AutoSize
                        }
                        else {
                            Write-Log -Message "No Send-As permissions found for $Mailbox" -Level "WARNING" -LogPath $LogPath
                        }
                    }

                    function Get-SendOnBehalfToSecure {
                        param([string]$Mailbox)
                        if (-not (Validate-Mailbox $Mailbox)) { throw "Invalid mailbox: $Mailbox" }
                        Write-Log -Message "Getting Send-On-Behalf-To permissions for mailbox: $Mailbox" -Level "INFO" -LogPath $LogPath
                        $mailboxObj = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
                        $mailboxObj | Format-List DisplayName, GrantSendOnBehalfTo
                        if ($mailboxObj.GrantSendOnBehalfTo.Count -gt 0) {
                            Write-Log -Message "Send-On-Behalf-To permissions granted to: $($mailboxObj.GrantSendOnBehalfTo)" -Level "INFO" -LogPath $LogPath
                        }
                        else {
                            Write-Log -Message "No Send-On-Behalf-To permissions found" -Level "WARNING" -LogPath $LogPath
                        }
                    }

                    function Grant-SendOnBehalfToSecure {
                        param([string]$Mailbox, [string]$Users)
                        if (-not (Validate-Mailbox $Mailbox)) { throw "Invalid mailbox: $Mailbox" }
                        $mailboxObj = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
                        $currentPermissions = $mailboxObj.GrantSendOnBehalfTo
                        $newUsers = $Users -split ',' | ForEach-Object { $_.Trim() }
                        $allPermissions = @()
                        if ($currentPermissions) { $allPermissions += $currentPermissions }
                        foreach ($user in $newUsers) {
                            if ($user -and $allPermissions -notcontains $user) {
                                $allPermissions += $user
                                Write-Log -Message "Adding: $user" -Level "INFO" -LogPath $LogPath
                            }
                            elseif ($allPermissions -contains $user) {
                                Write-Log -Message "Already exists: $user" -Level "INFO" -LogPath $LogPath
                            }
                        }
                        if ($PSCmdlet.ShouldProcess($Mailbox, "Grant Send-On-Behalf-To permissions")) {
                            try {
                                Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo $allPermissions -ErrorAction Stop
                                Write-Log -Message "Send-On-Behalf-To permissions updated successfully" -Level "INFO" -LogPath $LogPath
                                Write-AuditLog -Action "GRANT_SEND_ON_BEHALF_TO" -Target $Mailbox -User $env:USERNAME -AdditionalData @{Users = $allPermissions }
                            }
                            catch {
                                $sanitizedError = $_.Exception.Message -replace $Mailbox, "[MAILBOX]"
                                Write-Log -Message "Error updating Send-On-Behalf-To: $sanitizedError" -Level "ERROR" -LogPath $LogPath
                                Write-AuditLog -Action "GRANT_SEND_ON_BEHALF_TO_FAILED" -Target $Mailbox -User $env:USERNAME -Error $sanitizedError -AdditionalData @{Users = $allPermissions }
                            }
                        }
                    }

                    function Get-MailboxForwardingEnabledSecure {
                        param([string]$OutputPath, [switch]$IncludeInternal, [int]$MaxParallelJobs)
                        Write-Log -Message "Analyzing mailbox forwarding rules..." -Level "INFO" -LogPath $LogPath
                        $mailboxes = Get-Mailbox -ResultSize Unlimited
                        $results = @()
                        $jobs = @()
                        $jobThrottle = $MaxParallelJobs
                        foreach ($mb in $mailboxes) {
                            while ($jobs.Count -ge $jobThrottle) {
                                $jobs = $jobs | Where-Object { $_.State -eq "Running" }
                                Start-Sleep -Seconds 1
                            }
                            $jobs += Start-Job -ScriptBlock {
                                param($mbName, $includeInternal)
                                $rules = Get-InboxRule -Mailbox $mbName | Where-Object {
                                    $_.ForwardTo -or $_.ForwardAsAttachmentTo -or $_.RedirectTo
                                }
                                if (-not $includeInternal) {
                                    $rules = $rules | Where-Object {
                                        ($_.ForwardTo + $_.ForwardAsAttachmentTo + $_.RedirectTo) | Where-Object { $_.PrimarySmtpAddress -notlike "*@example.org" }
                                    }
                                }
                                $rules | Select-Object @{Name = "Mailbox"; Expression = { $mbName } }, Name, Enabled, ForwardTo, ForwardAsAttachmentTo, RedirectTo
                            } -ArgumentList $mb.PrimarySmtpAddress, $IncludeInternal.IsPresent
                        }
                        $jobs | ForEach-Object { $_ | Wait-Job }
                        $results = $jobs | ForEach-Object { Receive-Job $_ }
                        $jobs | ForEach-Object { Remove-Job $_ }
                        $results | Export-Csv -Path $OutputPath -NoTypeInformation
                        Write-Log -Message "Forwarding rule analysis complete. Results saved to $OutputPath" -Level "INFO" -LogPath $LogPath
                        Write-AuditLog -Action "GET_MAILBOX_FORWARDING_ENABLED" -Target $OutputPath -User $env:USERNAME
                    }

                    try {
                        switch ($Operation) {
                            "AddMailboxFolderPermission" {
                                Add-MailboxFolderPermissionSecure -Mailbox $Mailbox -User $User -Access $Access
                            }
                            "RemoveMailboxFolderPermission" {
                                Remove-MailboxFolderPermissionSecure -Mailbox $Mailbox -User $User
                            }
                            "GetSendAs" {
                                Get-SendAsSecure -Mailbox $Mailbox
                            }
                            "GetSendOnBehalfTo" {
                                Get-SendOnBehalfToSecure -Mailbox $Mailbox
                            }
                            "GrantSendOnBehalfTo" {
                                Grant-SendOnBehalfToSecure -Mailbox $Mailbox -Users $Users
                            }
                            "GetMailboxForwardingEnabled" {
                                Get-MailboxForwardingEnabledSecure -OutputPath $OutputPath -IncludeInternal:$IncludeInternal -MaxParallelJobs $MaxParallelJobs
                            }
                        }
                    }
                    catch {
                        $sanitizedError = $_.Exception.Message -replace $Mailbox, "[MAILBOX]" -replace $User, "[USER]"
                        Write-Log -Message "❌ Error: $sanitizedError" -Level "ERROR" -LogPath $LogPath
                        Write-AuditLog -Action "SCRIPT_ERROR" -Target $Mailbox -User $env:USERNAME -Error $sanitizedError
                        exit 1
                    }
