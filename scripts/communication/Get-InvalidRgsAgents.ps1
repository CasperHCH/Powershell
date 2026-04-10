<#
.SYNOPSIS
Finds invalid Skype for Business or Lync Response Group agents from recent event log entries.

.DESCRIPTION
Reads recent Response Group warning events, extracts affected agent identities,
maps them to Response Group agent groups, and optionally restores Enterprise
Voice or removes invalid agents from unmanaged groups.
#>

[CmdletBinding(DefaultParameterSetName = 'Report', SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, ParameterSetName = 'Restore')]
    [switch]$Restore,

    [Parameter(Mandatory = $false, ParameterSetName = 'Remove')]
    [switch]$Remove,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 500)]
    [int]$MaxEvents = 50,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogName = 'Application'
)

function Get-AgentUrisFromEventMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $uriMatches = [regex]::Matches($Message, 'sip:[^\s,;]+', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($match in $uriMatches) {
        $match.Value.TrimEnd('.', ',', ';', ')')
    }
}

function Get-AgentStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AgentUri
    )

    $csUser = Get-CsUser -Identity $AgentUri -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if (-not $csUser) {
        return [pscustomobject]@{
            User = $null
            Status = 'UserNotFound'
        }
    }

    $status = if ($csUser.EnterpriseVoiceEnabled) { 'EnterpriseVoiceEnabled' } else { 'EnterpriseVoiceDisabled' }
    [pscustomobject]@{
        User = $csUser
        Status = $status
    }
}

$events = @(Get-WinEvent -FilterHashtable @{ LogName = $LogName; Id = @(31137, 31138) } -MaxEvents $MaxEvents -ErrorAction Stop)
$agentUris = @($events | ForEach-Object { Get-AgentUrisFromEventMessage -Message $_.Message } | Sort-Object -Unique)
$allGroups = @(Get-CsRgsAgentGroup)

$results = foreach ($agentUri in $agentUris) {
    $agentState = Get-AgentStatus -AgentUri $agentUri
    $matchedGroups = @($allGroups | Where-Object { $_.AgentsByUri -contains $agentUri })

    if ($Restore -and $agentState.Status -eq 'EnterpriseVoiceDisabled' -and $agentState.User) {
        if ($PSCmdlet.ShouldProcess($agentUri, 'Enable Enterprise Voice')) {
            try {
                Set-CsUser -Identity $agentUri -EnterpriseVoiceEnabled $true -AudioVideoDisabled $false -WarningAction SilentlyContinue -ErrorAction Stop
                $agentState.Status = 'EnterpriseVoiceRestored'
            }
            catch {
                $agentState.Status = "RestoreFailed: $($_.Exception.Message)"
            }
        }
    }

    if ($matchedGroups.Count -eq 0) {
        [pscustomobject]@{
            AgentUri = $agentUri
            GroupName = $null
            OwnerPool = $null
            DistributionGroup = $null
            Status = $agentState.Status
            Action = 'NoGroupMatch'
        }
        continue
    }

    foreach ($group in $matchedGroups) {
        $action = 'None'

        if ($Remove -and $agentState.Status -ne 'EnterpriseVoiceEnabled') {
            if ($null -ne $group.DistributionGroupAddress) {
                $action = "DistributionGroupManaged:$($group.DistributionGroupAddress)"
            }
            elseif ($PSCmdlet.ShouldProcess($group.Name, "Remove $agentUri from agent group")) {
                try {
                    [void]$group.AgentsByUri.Remove($agentUri)
                    Set-CsRgsAgentGroup -Instance $group -ErrorAction Stop
                    $action = 'RemovedFromGroup'
                }
                catch {
                    $action = "RemoveFailed: $($_.Exception.Message)"
                }
            }
        }
        elseif ($Restore -and $agentState.Status -eq 'EnterpriseVoiceRestored') {
            $action = 'EnterpriseVoiceRestored'
        }

        [pscustomobject]@{
            AgentUri = $agentUri
            GroupName = $group.Name
            OwnerPool = $group.OwnerPool
            DistributionGroup = $group.DistributionGroupAddress
            Status = $agentState.Status
            Action = $action
        }
    }
}

$results | Sort-Object AgentUri, GroupName