<#
.SYNOPSIS
    Returns the KB article number of the most recently installed Windows Update on this machine.

.DESCRIPTION
    Intended for use as a Zabbix external check or user parameter script. When Zabbix executes
    this script on a monitored host, it receives a single string value - the KB number of the
    latest successfully installed Windows Update (e.g. "KB5034763").

    The script queries the full Windows Update installation history using the native Windows
    Update COM API (Microsoft.Update.Session), which provides richer history than Get-HotFix
    (WMI), including failed, aborted, and superseded update records.

    Microsoft Edge updates are excluded from the result as they install very frequently and
    would otherwise mask the last meaningful OS/security patch.

    The query runs inside a background job with a 25-second timeout. If the Windows Update
    agent is unresponsive or the history query stalls, the script outputs "TIMEOUT" so Zabbix
    can detect and alert on the condition rather than hanging indefinitely.

.OUTPUTS
    String - one of:
        KB...       The KB number of the most recent successful non-Edge update.
        TIMEOUT     The query did not complete within the allowed time.
        UNKNOWN     The query completed but returned no matching result.

.NOTES
    Designed to run locally on the target host (Zabbix agent context).
    Required: Windows Update service must be accessible via COM on the host.

    Windows Update COM API references:
        IUpdateSearcher.QueryHistory:
            https://msdn.microsoft.com/en-us/library/windows/desktop/aa386532
        IUpdateHistoryEntry.ResultCode:
            https://msdn.microsoft.com/en-us/library/windows/desktop/aa387095
#>

Function Get-HotfixAll
{
<#
.SYNOPSIS
    Retrieves the complete Windows Update installation history for a computer.

.DESCRIPTION
    Uses the Microsoft.Update.Session COM object to query the full Windows Update
    history log. Unlike Get-HotFix (which only reflects currently installed patches
    via WMI), this function returns every update attempt - including succeeded,
    failed, and aborted entries - sorted newest first.

.PARAMETER Computername
    The name of the computer to query. Currently used as context; the COM session
    runs locally via Invoke-Command without -ComputerName (localhost context).

.OUTPUTS
    PSObject with properties:
        ComputerName  - Hostname of the machine
        InstalledOn   - DateTime the update was attempted
        KBArticle     - Extracted KB number (e.g. "KB5034763"), or full title if no KB found
        Name          - Full update title as reported by Windows Update
        Status        - Human-readable result: NotStarted, InProgress, Succeeded,
                        SucceededWithErrors, Failed, Aborted
#>
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$Computername
    )

    Invoke-Command -ScriptBlock {

        # Open a Windows Update COM session on the local machine
        $Session  = New-Object -ComObject Microsoft.Update.Session
        $Searcher = $Session.CreateUpdateSearcher()

        # Retrieve the total number of history entries so we can fetch them all at once
        $HistoryCount = $Searcher.GetTotalHistoryCount()

        $Searcher.QueryHistory(0, $HistoryCount) | ForEach-Object -Process {

            # Extract KB token from title (supports formats like KB5034763, KB 5034763, KB-5034763)
            # If no KB token is found, fall back to the full title string
            $Title = $null
            if ($_.Title -match '(?i)\bKB[\s-]?(\d+)\b') {
                $Title = 'KB' + $Matches[1]
            } else {
                $Title = $_.Title
            }

            # Map the numeric ResultCode to a readable status string
            $Result = $null
            Switch ($_.ResultCode) {
                0 { $Result = 'NotStarted' }
                1 { $Result = 'InProgress' }
                2 { $Result = 'Succeeded' }
                3 { $Result = 'SucceededWithErrors' }
                4 { $Result = 'Failed' }
                5 { $Result = 'Aborted' }
                default { $Result = $_ }
            }

            New-Object -TypeName PSObject -Property @{
                ComputerName = $ENV:Computername
                InstalledOn  = Get-Date -Date $_.Date
                KBArticle    = $Title
                Name         = $_.Title
                Status       = $Result
            }

        } | Sort-Object -Descending -Property InstalledOn |
            Select-Object -Property *
    }
}

# ---- Main: return the latest KB number for Zabbix ----

# Timeout in seconds before the Windows Update query is abandoned
$TimeoutSeconds = 25

# Run the query in a background job so we can enforce the timeout.
# The function definition is serialised as a string and re-evaluated inside the
# job's isolated runspace, since jobs do not inherit the caller's scope.
$job = Start-Job -ScriptBlock {
    param($fn)
    . ([ScriptBlock]::Create($fn))

    (Get-HotfixAll -Computername localhost |
        Where-Object {
            $_.Status -eq 'Succeeded' -and
            $_.InstalledOn -is [datetime] -and
            $_.InstalledOn.Year -ge 2000 -and
            $_.KBArticle -match '^KB\d{4,}$' -and
            $_.KBArticle -notlike '*Edge*'
        }
    ).KBArticle | Select-Object -First 1

} -ArgumentList ${function:Get-HotfixAll}.ToString()

# Wait for completion without relying on Wait-Job (some hosts/runspaces expose job cmdlets inconsistently)
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$completed = $false

while ((Get-Date) -lt $deadline) {
    $jobState = (Get-Job -Id $job.Id -ErrorAction SilentlyContinue).State

    if ($jobState -in @('Completed', 'Failed', 'Stopped')) {
        $completed = $true
        break
    }

    Start-Sleep -Milliseconds 250
}

if (-not $completed) {
    # Query stalled - stop and remove the job, then report TIMEOUT to Zabbix
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    Write-Output "TIMEOUT"
} else {
    $t = Receive-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

    if ($t) {
        $t.ToString()
    } else {
        # Query finished but no matching update was found
        Write-Output "UNKNOWN"
    }
}