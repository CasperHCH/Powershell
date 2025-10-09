<#
.SYNOPSIS
    Retrieves calendar permissions for a specified mailbox
.DESCRIPTION
    This function connects to Exchange Online and retrieves the calendar folder permissions
    for a specified mailbox. It automatically connects to Exchange if not already connected.
.PARAMETER Identity
    The mailbox identity (email address, alias, or distinguished name) to retrieve calendar permissions for.
.EXAMPLE
    Get-CalPerm -Identity "john.doe@contoso.com"
    Retrieves calendar permissions for the specified mailbox.
.EXAMPLE
    Get-CalPerm -Identity "jdoe"
    Retrieves calendar permissions using the mailbox alias.
.NOTES
    Requires Exchange Online PowerShell connection and appropriate permissions.
    Automatically connects to Exchange Online if not already connected.
#>
Function Get-CalPerm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Specify the mailbox identity.")]
        [ValidateNotNullOrEmpty()]
        [string]$Identity
    )

    # Connect to Exchange Management Shell if not already
    if (!(Get-Command Get-Mailbox -ErrorAction SilentlyContinue)) {
        Write-Verbose 'Connecting to Exchange Online..' -Verbose
        Connect-ExchangeOnline
    }

    $MBX = Get-Mailbox -Identity $Identity

    $CalendarName = (Get-MailboxFolderStatistics -Identity $MBX.Alias -FolderScope Calendar | Select-Object -First 1).Name
    $folderID = "$($MBX.Alias):\$CalendarName"
    Get-MailboxFolderPermission -Identity $folderID | Format-Table -AutoSize
}

# Example usage:
# Get-CalPerm -Identity "user@example.com"