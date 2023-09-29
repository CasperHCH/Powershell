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
    where {$_.msexchdelegatelistlink -ne ""} | 
    Select-Object name, @{N="msExchDelegateListLink"; e={$_.msexchdelegatelistlink}}, UserPrincipalName 
    $targets= @()

    foreach ($User in $automapped) {
        $Delegates = $user | select @{ N="Name"; e= {$_ |select -ExpandProperty MsExchDelegateListLink}} 
        $delegatesExp = $Delegates | Select -ExpandProperty Name 
    
        foreach ($delegate in $delegatesExp) {
            If ($delegate -notlike "CN=Administrator*") {
                $DelegatedUserUPN = Get-ADUser -Identity ($Delegate.tostring()) -Properties Userprincipalname | Select UserPrincipalName 
                $DelegatedName = ($Delegate.split(",")[0]).replace("CN=","") 
                $target = New-Object psobject 
                $target | Add-Member -type noteproperty -Name "User Name" -Value ($user.Name) -force 
                $target | Add-Member -type noteproperty -Name "DelegatedUser" -Value ($DelegatedName) -force 
                $target | Add-Member -type noteproperty -Name "UserPrincipalName" -Value ($user.UserPrincipalName) -force 
                $target | Add-Member -type noteproperty -Name "DelegatedUser" -Value ($DelegatedName) -force 
                $target | Add-Member -type noteproperty -Name "DelegatedUserUPN" -Value ($DelegatedUserUPN.UserPrincipalName) -force 
                $targets += $target
            }
        }
    }
}

end {
    $targets # | Export-Csv C:\SCRIPTS\AutoMapped_Mailboxes_With_Delegates.csv -NoTypeInformation
}