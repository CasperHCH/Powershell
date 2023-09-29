    Param(
      [Parameter(Mandatory=$True)]
      [String]$Identity
    )
    Get-Mailbox -Identity $Identity |Get-ADPermission | Where-Object {$_.extendedrights -like "*send*"}