<#
.SYNOPSIS
	This script will list all AD users mailbox Automappings.

.DESCRIPTION
	This script will list all AD users mailbox Automappings from the attribute 'msexchdelegatelistlink' on the userobject in AD.

.EXAMPLE
	PS C:\>NSG-GetAllAutomappings.ps1

	This example will return all ad users mailbox automappings.

.NOTES
    Written by   : NSG @ EET
    Release date :
#>

[CmdletBinding()]
param()

Begin {
    Try {
        Import-Module ActiveDirectory -ErrorAction Stop
    }

    Catch {
        Write-Warning $_
        Break
    }
}

process {
    $automapped = Get-ADUser -Filter * -Properties msexchdelegatelistlink, UserPrincipalName |
    where {$_.msexchdelegatelistlink -ne $null} |
    Select-Object name, @{N="DelegateListLink"; e={$_.msexchdelegatelistlink}}, UserPrincipalName
    $targets= @()

    foreach ($User in $automapped) {
        $Delegates = $user | Select-Object @{ N="Name"; e= {$_ |Select-Object -ExpandProperty MsExchDelegateListLink}}
        $delegatesExp = $Delegates | Select-Object -ExpandProperty Name

        foreach ($delegate in $delegatesExp) {
            If ($delegate -notlike "") {
                $DelegatedUserUPN = Get-ADUser -Identity ($Delegate.tostring()) -Properties Userprincipalname | Select-Object UserPrincipalName
                $DelegatedName = ($Delegate.split("/")[0]).replace("CN=","")
                $target = New-Object psobject
                $target | Add-Member -type noteproperty -Name "UserName" -Value ($user.Name) -force
                $target | Add-Member -type noteproperty -Name "DelegateName" -Value ($DelegatedName) -force
                $target | Add-Member -type noteproperty -Name "UserPrincipalName" -Value ($user.UserPrincipalName) -force
                $target | Add-Member -type noteproperty -Name "DelegateDisplayName" -Value ($DelegatedName) -force
                $target | Add-Member -type noteproperty -Name "DelegateUPN" -Value ($DelegatedUserUPN.UserPrincipalName) -force
                $targets += $target
            }
        }
    }
}

end {
    $targets # | Export-Csv C:\SCRIPTS\AutoMapped_Mailboxes_With_Delegates.csv -NoTypeInformation
}
