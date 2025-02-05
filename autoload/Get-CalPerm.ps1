######################################## 
# Get-CalPerm.ps1 -Identify <mailbox>
Function Get-CalPerm {

    param(
        [Parameter(Mandatory = $true, HelpMessage=)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity
    )

    # Connect to Exchange Management Shell if not already
    if (!(Get-Command Get-Mailbox -ErrorAction SilentlyContinue)) {
        Write-Host 
        Connect-ExchangeOnline
    }

    $MBX = Get-Mailbox $identity

    $CalendarName = (Get-MailboxFolderStatistics -Identity $MBX.alias -FolderScope Calendar | Select-Object -First 1).Name
    $folderID = $MBX.alias + ':\' + $CalendarName
    Get-MailboxFolderPermission -Identity $folderID | ft -AutoSize
}
