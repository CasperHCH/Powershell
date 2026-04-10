<#
.SYNOPSIS
Exports Active Directory user contact details to a VCF file.

.DESCRIPTION
Queries Active Directory for users in the specified search base and writes contact
details such as display name, email address, mobile number, and office phone
to a single vCard output file.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = 'OU or container DN to search for contacts.')]
    [ValidateNotNullOrEmpty()]
    [string]$SearchBase,

    [Parameter(Mandatory = $false, HelpMessage = 'Destination VCF file path.')]
    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath 'ADContacts.vcf'),

    [Parameter(Mandatory = $false)]
    [switch]$IncludeDisabled
)

Import-Module ActiveDirectory -ErrorAction Stop

function ConvertTo-VCardText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $User
    )

    $escape = {
        param([string]$Value)
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return ''
        }

        return $Value.Replace(';', '\;').Replace(',', '\,')
    }

    @(
        'BEGIN:VCARD'
        'VERSION:3.0'
        "N:$(& $escape $User.Surname);$(& $escape $User.GivenName);;;"
        "FN:$(& $escape $User.Name)"
        "EMAIL;TYPE=INTERNET:$(& $escape $User.Mail)"
        "TEL;TYPE=CELL:$(& $escape $User.Mobile)"
        "TEL;TYPE=WORK,VOICE:$(& $escape $User.OfficePhone)"
        'END:VCARD'
    ) -join [Environment]::NewLine
}

$ldapFilter = if ($IncludeDisabled) {
    '(objectCategory=person)'
}
else {
    '(&(objectCategory=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))'
}

$users = Get-ADUser -LDAPFilter $ldapFilter -SearchBase $SearchBase -Properties GivenName, Surname, Mail, Mobile, OfficePhone, DisplayName |
    Where-Object { $_.Mail -or $_.Mobile -or $_.OfficePhone } |
    Select-Object @{ Name = 'Name'; Expression = { $_.DisplayName } }, GivenName, Surname, Mail, Mobile, OfficePhone

$vCards = foreach ($user in $users) {
    ConvertTo-VCardText -User $user
}

Set-Content -Path $OutputPath -Value ($vCards -join ([Environment]::NewLine + [Environment]::NewLine)) -Encoding UTF8
Write-Output "Created $($users.Count) vCards at $OutputPath"