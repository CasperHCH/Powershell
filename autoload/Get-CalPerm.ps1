########################################
# Get-CalPerm.ps1 -Identity <mailbox>
Function Get-CalPerm {

    param(
        [Parameter(Mandatory = $true, HelpMessage = "Specify the mailbox identity.")]
        [ValidateNotNullOrEmpty()]
        [string]$Identity
    )

    # Connect to Exchange Management Shell if not already
    if (!(Get-Command Get-Mailbox -ErrorAction SilentlyContinue)) {
        Write-Host 'Connecting to Exchange Online ..'
        Connect-ExchangeOnline
    }

    $MBX = Get-Mailbox -Identity $Identity

    $CalendarName = (Get-MailboxFolderStatistics -Identity $MBX.Alias -FolderScope Calendar | Select-Object -First 1).Name
    $folderID = "$($MBX.Alias):\$CalendarName"
    Get-MailboxFolderPermission -Identity $folderID | Format-Table -AutoSize
}

# Example usage:
# Get-CalPerm -Identity "user@example.com"