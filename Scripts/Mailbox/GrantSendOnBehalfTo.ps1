#Here is a simple requirement . you have a requirement to assign GrantsendonBehalfto 
#permissions on all mailboxes with out overwriting existing Permissions.
    Param(
      [Parameter(Mandatory=$True)]
      [String]$Identity,
      [String]$Users
    )
#get-mailbox -Identity $Identity | set-mailbox –grantsendonbehalfto -Identity $Users

$a = get-mailbox -Identity $Identity | select-object grantsendonbehalfto 

$a.grantsendonbehalfto += $Users[0]

get-mailbox -Identity $Identity |set-mailbox -grantsendonbehalfto $($a.grantsendonbehalfto)
