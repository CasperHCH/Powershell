######################################## 
# Set-CalPerm.ps1 -Identify <mailbox> -User <xxx> -Permission <permission> 
Function Set-CalPerm {

    param (
        [Parameter(Mandatory = $true, HelpMessage="Enter a mailbox where you apply permission to")]
        [ValidateNotNullOrEmpty()]
        [string]$Identity ,

        [Parameter(Mandatory = $true, HelpMessage="Enter a user/group who will be granted the permission  syntax domain\xxx might be needed")]
        [ValidateNotNullOrEmpty()]
        [string]$User = "",

        [parameter(Mandatory = $true, HelpMessage="Enter a valid permission set")]
        [ValidateSet("ReadItems","CreateItems","EditOwnedItems","DeleteOwnedItems","EditAllItems","DeleteAllItems","CreateSubfolders","FolderOwner","FolderContact","FolderVisible","None","Owner","PublishingEditor","Editor","PublishingAuthor","Author","NonEditingAuthor","Reviewer","Contributor","AvailabilityOnly","LimitedDetails","Remove","Delete")]
        [string]$Permission = ""
    )

    # Connect to Exchange Management Shell if not already
    if (!(Get-Command Get-Mailbox -ErrorAction SilentlyContinue)) {
        Connect-ExchangeOnline
    }

    $MBX = Get-Mailbox $identity

    $CalendarName = (Get-MailboxFolderStatistics -Identity $MBX.alias -FolderScope Calendar | Select-Object -First 1).Name
    $folderID = $MBX.alias + ':\' + $CalendarName

    if ($Permission -eq 'remove' -or $Permission -eq 'delete') {
        # special case, remove permission from user
        Remove-MailboxFolderPermission -Identity $folderID -User $User -Confirm:$False

        # display permissions for $mailbox
        Get-MailboxFolderPermission -Identity $folderID | ft -AutoSize
    }

    else {
        $i = @(Get-MailboxFolderPermission -Identity $folderID -User $User -ErrorAction SilentlyContinue).count
        if ($i -eq 0) {
            # user is not in ACL, add permission
            Add-MailboxFolderPermission -Identity $folderID -User $User -AccessRights $Permission > $Null
        }

        else {
            # user is in ACL, change permission
            Set-MailboxFolderPermission -Identity $folderID -User $User -AccessRights $Permission
        }
        # display new permission for $user
        Get-MailboxFolderPermission -Identity $folderID -User $User
    }
}