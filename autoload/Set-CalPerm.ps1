######################################## 
# Set-CalPerm.ps1 -Identify <mailbox> -User <xxx> -Permission <permission> 
Function Set-CalPerm {

    param (
        [Parameter(Mandatory = $true, HelpMessage=)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity ,

        [Parameter(Mandatory = $true, HelpMessage=)]
        [ValidateNotNullOrEmpty()]
        [string]$User = ,

        [parameter(Mandatory = $true, HelpMessage=)]
        [ValidateSet(,,,,,,,,,,,,,,,,,,,,,,)]
        [string]$Permission = 
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
