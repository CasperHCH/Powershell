Function NSG-GetMailboxAutomapping {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$Identity      
    )

        Begin {
            Try {
            Import-Module ActiveDirectory -ErrorAction Stop
        }

        Catch {
            Write-Warning $_
            Break
        }
    }

    Process {
        Get-ADUser -Identity $Identity -Properties msExchDelegateListBL | select -ExpandProperty msExchDelegateListBL
    }
}
