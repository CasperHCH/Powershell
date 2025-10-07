Function Get-UserDelegateAutomapping {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$User
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
        Get-ADUser -Identity $User -Properties msExchDelegateListLink | Select-Object -ExpandProperty msExchDelegateListLink
    }
}
