<#
.SYNOPSIS
Performs a controlled Active Directory offboarding workflow for a user.

.DESCRIPTION
Disables or schedules expiration for a user account, optionally moves the user to
another OU, exports group membership, reassigns direct reports, and performs
available mailbox cleanup actions with audit logging.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true, HelpMessage = 'SamAccountName, distinguished name, or UPN of the user to offboard.')]
    [ValidateNotNullOrEmpty()]
    [string]$Identity,

    [Parameter(Mandatory = $false, HelpMessage = 'Date to disable the account. Defaults to today.')]
    [datetime]$DisableOnDate = (Get-Date).Date,

    [Parameter(Mandatory = $false, HelpMessage = 'Move the user to this OU after disablement.')]
    [string]$DeletionOuPath,

    [Parameter(Mandatory = $false, HelpMessage = 'Reassign direct reports to this manager SamAccountName or distinguished name.')]
    [string]$ChangeManagerTo,

    [Parameter(Mandatory = $false, HelpMessage = 'Directory used for exported group membership files.')]
    [string]$GroupExportDirectory = (Join-Path -Path $PSScriptRoot -ChildPath 'OffboardingData\Groups'),

    [Parameter(Mandatory = $false, HelpMessage = 'Directory used for exported mailbox alias files.')]
    [string]$AliasExportDirectory = (Join-Path -Path $PSScriptRoot -ChildPath 'OffboardingData\Aliases'),

    [Parameter(Mandatory = $false, HelpMessage = 'Forward mailbox to this SMTP address when mailbox cmdlets are available.')]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$ForwardingAddress,

    [Parameter(Mandatory = $false, HelpMessage = 'Grant mailbox access to this user when mailbox cmdlets are available.')]
    [string]$GrantMailboxAccessTo,

    [Parameter(Mandatory = $false, HelpMessage = 'Automatic reply message to configure when mailbox cmdlets are available.')]
    [string]$AutoReplyMessage,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveGroupMemberships,

    [Parameter(Mandatory = $false)]
    [switch]$ExportMailboxAliases
)

Set-StrictMode -Version Latest

$script:SessionId = [guid]::NewGuid().ToString('N').Substring(0, 8)
$script:LogPath = Join-Path -Path $PSScriptRoot -ChildPath 'offboarding.log'

function Write-ScriptLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'AUDIT')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [switch]$Sensitive
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$script:SessionId] [$Level] [$env:USERNAME] $Message"
    Add-Content -Path $script:LogPath -Value $entry

    if ($Sensitive) {
        return
    }

    switch ($Level) {
        'ERROR' { Write-Error $Message }
        'WARNING' { Write-Warning $Message }
        default { Write-Verbose $Message }
    }
}

function Write-AuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [string]$Error
    )

    $payload = [pscustomobject]@{
        Timestamp = Get-Date -Format 'o'
        SessionId = $script:SessionId
        Action = $Action
        User = $env:USERNAME
        Target = $Target
        Error = $Error
        ComputerName = $env:COMPUTERNAME
        ScriptName = $MyInvocation.ScriptName
    } | ConvertTo-Json -Compress

    Write-ScriptLog -Level 'AUDIT' -Message $payload -Sensitive
}

function Initialize-Directory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        $null = New-Item -Path $Path -ItemType Directory -Force
    }
}

function Resolve-ExchangeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        $command = Get-Command -Name $candidate -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Name
        }
    }

    return $null
}

function Get-OffboardingUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )

    Get-ADUser -Identity $Identity -Properties DisplayName, DistinguishedName, CanonicalName, EmailAddress,
        SamAccountName, Company, UserPrincipalName, DirectReports, Manager, Description, MemberOf, PrimaryGroupId
}

function Export-GroupMembership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $User,

        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    Initialize-Directory -Path $Directory
    $path = Join-Path -Path $Directory -ChildPath ("{0}-groups.csv" -f $User.SamAccountName)

    $groups = @(Get-ADPrincipalGroupMembership -Identity $User -ErrorAction Stop |
        Sort-Object Name |
        Select-Object Name, SamAccountName, DistinguishedName, GroupCategory, GroupScope)

    $groups | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
    Write-AuditLog -Action 'GROUP_EXPORT' -Target $path
    return $groups
}

function Remove-SecondaryGroupMembership {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        $User,

        [Parameter(Mandatory = $true)]
        [object[]]$Groups
    )

    foreach ($group in $Groups) {
        if ($group.Name -eq 'Domain Users') {
            continue
        }

        if ($PSCmdlet.ShouldProcess($group.Name, "Remove $($User.SamAccountName) from group")) {
            Remove-ADGroupMember -Identity $group.DistinguishedName -Members $User.DistinguishedName -Confirm:$false -ErrorAction Stop
            Write-AuditLog -Action 'GROUP_MEMBERSHIP_REMOVED' -Target $group.DistinguishedName
        }
    }
}

function Set-DirectReportManager {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        $User,

        [Parameter(Mandatory = $true)]
        [string]$ManagerIdentity
    )

    $reports = @($User.DirectReports)
    if ($reports.Count -eq 0) {
        return
    }

    $manager = Get-ADUser -Identity $ManagerIdentity -ErrorAction Stop

    foreach ($report in $reports) {
        if ($PSCmdlet.ShouldProcess($report, "Set manager to $($manager.SamAccountName)")) {
            Set-ADUser -Identity $report -Manager $manager.DistinguishedName -ErrorAction Stop
            Write-AuditLog -Action 'DIRECT_REPORT_REASSIGNED' -Target $report
        }
    }
}

function Export-MailAlias {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $User,

        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    $getMailboxCommand = Resolve-ExchangeCommand -Candidates @('Get-CloudMailbox', 'Get-LocalMailbox', 'Get-Mailbox')
    if (-not $getMailboxCommand) {
        Write-ScriptLog -Level 'WARNING' -Message 'Mailbox alias export skipped because no mailbox cmdlet is available.'
        return
    }

    $mailbox = & $getMailboxCommand -Identity $User.UserPrincipalName -ErrorAction Stop
    Initialize-Directory -Path $Directory
    $path = Join-Path -Path $Directory -ChildPath ("{0}-aliases.txt" -f $User.SamAccountName)
    @($mailbox.EmailAddresses) | Set-Content -Path $path -Encoding UTF8
    Write-AuditLog -Action 'MAIL_ALIAS_EXPORT' -Target $path
}

function Set-MailboxForwardingIfRequested {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        $User,

        [Parameter(Mandatory = $true)]
        [string]$ForwardingAddress
    )

    $setMailboxCommand = Resolve-ExchangeCommand -Candidates @('Set-CloudMailbox', 'Set-LocalMailbox', 'Set-Mailbox')
    if (-not $setMailboxCommand) {
        Write-ScriptLog -Level 'WARNING' -Message 'Mailbox forwarding skipped because no mailbox cmdlet is available.'
        return
    }

    if ($PSCmdlet.ShouldProcess($User.UserPrincipalName, "Configure forwarding to $ForwardingAddress")) {
        & $setMailboxCommand -Identity $User.UserPrincipalName -ForwardingAddress $ForwardingAddress -DeliverToMailboxAndForward $true -ErrorAction Stop
        Write-AuditLog -Action 'MAIL_FORWARDING_SET' -Target $User.UserPrincipalName
    }
}

function Grant-MailboxAccessIfRequested {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        $User,

        [Parameter(Mandatory = $true)]
        [string]$GrantMailboxAccessTo
    )

    if (-not (Get-Command -Name Add-MailboxPermission -ErrorAction SilentlyContinue)) {
        Write-ScriptLog -Level 'WARNING' -Message 'Mailbox access grant skipped because Add-MailboxPermission is unavailable.'
        return
    }

    $grantUser = Get-ADUser -Identity $GrantMailboxAccessTo -ErrorAction Stop
    if ($PSCmdlet.ShouldProcess($User.UserPrincipalName, "Grant mailbox access to $($grantUser.SamAccountName)")) {
        Add-MailboxPermission -Identity $User.UserPrincipalName -User $grantUser.SamAccountName -AccessRights FullAccess -InheritanceType All -AutoMapping $true -ErrorAction Stop
        Write-AuditLog -Action 'MAILBOX_PERMISSION_GRANTED' -Target $User.UserPrincipalName
    }
}

function Set-AutoReplyIfRequested {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        $User,

        [Parameter(Mandatory = $true)]
        [string]$AutoReplyMessage
    )

    $command = Resolve-ExchangeCommand -Candidates @('Set-CloudMailboxAutoReplyConfiguration', 'Set-LocalMailboxAutoReplyConfiguration', 'Set-MailboxAutoReplyConfiguration')
    if (-not $command) {
        Write-ScriptLog -Level 'WARNING' -Message 'Automatic reply configuration skipped because no mailbox auto-reply cmdlet is available.'
        return
    }

    if ($PSCmdlet.ShouldProcess($User.UserPrincipalName, 'Configure automatic replies')) {
        & $command -Identity $User.UserPrincipalName -AutoReplyState Enabled -ExternalAudience All -InternalMessage $AutoReplyMessage -ExternalMessage $AutoReplyMessage -ErrorAction Stop
        Write-AuditLog -Action 'AUTO_REPLY_SET' -Target $User.UserPrincipalName
    }
}

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    $user = Get-OffboardingUser -Identity $Identity
    Write-AuditLog -Action 'OFFBOARDING_START' -Target $user.DistinguishedName

    if ($ChangeManagerTo) {
        Set-DirectReportManager -User $user -ManagerIdentity $ChangeManagerTo
    }

    $groupMembership = Export-GroupMembership -User $user -Directory $GroupExportDirectory

    if ($DisableOnDate.Date -le (Get-Date).Date) {
        if ($PSCmdlet.ShouldProcess($user.SamAccountName, 'Disable AD account')) {
            Disable-ADAccount -Identity $user.DistinguishedName -ErrorAction Stop
            Set-ADUser -Identity $user.DistinguishedName -Replace @{ logonHours = ([byte[]](0..20 | ForEach-Object { 0 })) } -ErrorAction Stop
            Write-AuditLog -Action 'ACCOUNT_DISABLED' -Target $user.DistinguishedName
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Set AD account expiration to $DisableOnDate")) {
            Set-ADAccountExpiration -Identity $user.DistinguishedName -DateTime $DisableOnDate -ErrorAction Stop
            Write-AuditLog -Action 'ACCOUNT_EXPIRATION_SET' -Target $user.DistinguishedName
        }
    }

    if ($DeletionOuPath) {
        if ($PSCmdlet.ShouldProcess($user.DistinguishedName, "Move to $DeletionOuPath")) {
            Move-ADObject -Identity $user.DistinguishedName -TargetPath $DeletionOuPath -ErrorAction Stop
            Write-AuditLog -Action 'ACCOUNT_MOVED' -Target $DeletionOuPath
            $user = Get-OffboardingUser -Identity $Identity
        }
    }

    if ($RemoveGroupMemberships) {
        Remove-SecondaryGroupMembership -User $user -Groups $groupMembership
    }

    if ($ExportMailboxAliases) {
        Export-MailAlias -User $user -Directory $AliasExportDirectory
    }

    if ($ForwardingAddress) {
        Set-MailboxForwardingIfRequested -User $user -ForwardingAddress $ForwardingAddress
    }

    if ($GrantMailboxAccessTo) {
        Grant-MailboxAccessIfRequested -User $user -GrantMailboxAccessTo $GrantMailboxAccessTo
    }

    if ($AutoReplyMessage) {
        Set-AutoReplyIfRequested -User $user -AutoReplyMessage $AutoReplyMessage
    }

    Write-AuditLog -Action 'OFFBOARDING_COMPLETE' -Target $user.DistinguishedName
}
catch {
    Write-AuditLog -Action 'OFFBOARDING_FAILED' -Target $Identity -Error $_.Exception.Message
    Write-ScriptLog -Level 'ERROR' -Message $_.Exception.Message
    throw
}