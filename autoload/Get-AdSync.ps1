function Get-AdSync {
    [CmdletBinding()]
    Param()

    try {
        Invoke-Command -ComputerName prod-adsync-01 -ScriptBlock { Get-ADSyncScheduler }
    }

    catch {
        Write-Warning $_.Exception.Message
        Break
    }
}