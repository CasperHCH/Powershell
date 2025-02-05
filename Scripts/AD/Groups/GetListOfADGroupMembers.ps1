Param(
      [Parameter(Mandatory=$True)]
      [String]$Identity
    )
},
  @{Name=;Expression={(Get-ADUser $_.distinguishedName -Properties Title).title}}
}
GetADGroupInfo
