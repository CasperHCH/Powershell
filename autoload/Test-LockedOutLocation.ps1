#Requires -Version 2.0
Function Test-LockedOutLocation {
<#
.SYNOPSIS
	This function will test if user is locked out in Windows AD.

.DESCRIPTION
	The function will test if user is locked out in Windows AD.
	The function will display the BadPasswordTime attribute on all of the domain controllers.

.EXAMPLE
	PS C:\>Test-LockedOut mao-de

	This example will test if the user Manuel Orlitzky is locked out.

.NOTE
	This function is only compatible with an environment where the domain controller(s) with the PDCe role to be running Windows Server 2008 SP2 and up.  
	The script is also dependent of the ActiveDirectory PowerShell module, which requires the AD Web services to be running on at least one domain controller.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        [String]$Identity      
    )

    Begin {
        $DCCounter = 0 
        $LockedOutStats = @()   
                
        Try {
            Import-Module ActiveDirectory -ErrorAction Stop
        }

        Catch {
           Write-Warning $_
           Break
        }
    }

    Process {
        
        #Get all domain controllers in domain exepct for Read Only DC's
		$DomainControllers = Get-ADDomainController -Filter {Name -notlike "*RODC*"}
        $PDCEmulator = ($DomainControllers | Where-Object {$_.OperationMasterRoles -contains "PDCEmulator"})

        Write-Verbose "Finding domain controllers in the domain"
        Foreach($DC in $DomainControllers) {
            $DCCounter++
            Write-Progress -Activity "Contacting $($DomainControllers.count) DCs for lockout info" -Status "Querying $($DC.Hostname)" -PercentComplete (($DCCounter/$DomainControllers.Count) * 100)
            
            Try {
                $UserInfo = Get-ADUser -Identity $Identity  -Server $DC.Hostname -Properties AccountLockoutTime,LastBadPasswordAttempt,BadPwdCount,LockedOut -ErrorAction Stop
            }

            Catch {
                Write-Warning $_
                Continue
            }

            If ($UserInfo.LastBadPasswordAttempt) {
                $LockedOutStats += New-Object -TypeName PSObject -Property @{
                    Name                   = $UserInfo.SamAccountName
                    SID                    = $UserInfo.SID.Value
                    LockedOut              = $UserInfo.LockedOut
                    BadPwdCount            = $UserInfo.BadPwdCount
                    BadPasswordTime        = $UserInfo.BadPasswordTime            
                    DomainController       = $DC.Hostname
                    AccountLockoutTime     = $UserInfo.AccountLockoutTime
                    LastBadPasswordAttempt = ($UserInfo.LastBadPasswordAttempt).ToLocalTime()
                }
            }
        }
        
        $LockedOutStats | Format-Table -Property Name,LockedOut,DomainController,BadPwdCount,AccountLockoutTime,LastBadPasswordAttempt -AutoSize
    }
}