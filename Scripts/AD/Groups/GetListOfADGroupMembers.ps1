    Param(
      [Parameter(Mandatory=$True)]
      [String]$Identity
    )
Function GetADGroupInfo {
  Get-ADGroupMember -Identity $Identity |
  Select samAccountName,Name,
  @{Name="DisplayName";Expression={(Get-ADUser $_.distinguishedName -Properties Displayname).Displayname}},
  @{Name="Title";Expression={(Get-ADUser $_.distinguishedName -Properties Title).title}}
}
GetADGroupInfo
