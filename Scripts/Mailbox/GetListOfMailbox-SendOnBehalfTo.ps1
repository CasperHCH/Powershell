Param(
      [Parameter(Mandatory=$True)]
      [String]$Identity
    )
    Get-Mailbox -identity $Identity | fl displayname, GrantSendOnBehalfTo
