########################################
# Set-CalPerm.ps1 -Identity <mailbox> -User <xxx> -Permission <permission>
Function Set-CalPerm {

    param (
        [Parameter(Mandatory = $true, HelpMessage = "Specify the mailbox identity.")]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,

        [Parameter(Mandatory = $true, HelpMessage = "Specify the user to set permissions for.")]
        [ValidateNotNullOrEmpty()]
        [string]$User,

        [Parameter(Mandatory = $true, HelpMessage = "Specify the permission to set.")]
        [ValidateSet("Owner", "PublishingEditor", "Editor", "PublishingAuthor", "Author", "NonEditingAuthor", "Reviewer", "Contributor", "AvailabilityOnly", "LimitedDetails", "Remove")]
        [string]$Permission
    )

    # Connect to Exchange Management Shell if not already
    if (!(Get-Command Get-Mailbox -ErrorAction SilentlyContinue)) {
        Connect-ExchangeOnline
    }

    $MBX = Get-Mailbox -Identity $Identity

    $CalendarName = (Get-MailboxFolderStatistics -Identity $MBX.Alias -FolderScope Calendar | Select-Object -First 1).Name
    $folderID = "$($MBX.Alias):\$CalendarName"

    if ($Permission -eq 'Remove') {
        # Special case, remove permission from user
        Remove-MailboxFolderPermission -Identity $folderID -User $User -Confirm:$False

        # Display permissions for the mailbox
        Get-MailboxFolderPermission -Identity $folderID | Format-Table -AutoSize
    } else {
        $existingPermission = Get-MailboxFolderPermission -Identity $folderID -User $User -ErrorAction SilentlyContinue
        if (-not $existingPermission) {
            # User is not in ACL, add permission
            Add-MailboxFolderPermission -Identity $folderID -User $User -AccessRights $Permission > $Null
        } else {
            # User is in ACL, change permission
            Set-MailboxFolderPermission -Identity $folderID -User $User -AccessRights $Permission
        }
        # Display new permission for the user
        Get-MailboxFolderPermission -Identity $folderID -User $User
    }
}

# Example usage:
# Set-CalPerm -Identity "user@example.com" -User "anotheruser@example.com" -Permission "Editor"