#Requires -Version 2.0

    <#
    .SYNOPSIS
        This function will test if a user is locked out in Windows AD.
    .DESCRIPTION
        The function will test if a user is locked out in Windows AD.
        The function will display the BadPasswordTime attribute on all of the domain controllers.
    .EXAMPLE
        PS C:\>Test-LockedOutLocation -Identity "mao-de"
        This example will test if the user Manuel Orlitzky is locked out.
    .NOTES
        This function is only compatible with an environment where the domain controller(s) with the PDCe role are running Windows Server 2008 SP2 and up.
        The script is also dependent on the ActiveDirectory PowerShell module, which requires the AD Web services to be running on at least one domain controller.
    #>
    Function Test-LockedOutLocation {
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
            } Catch {
               Write-Warning "Failed to import ActiveDirectory module: $_"
               Break
            }
        }

        Process {
            # Get all domain controllers in the domain except for Read Only DCs
            $DomainControllers = Get-ADDomainController -Filter {Name -notlike "*RODC*"}
            $PDCEmulator = ($DomainControllers | Where-Object {$_.OperationMasterRoles -contains "PDCEmulator"})

            Write-Verbose "Found $($DomainControllers.Count) domain controllers."

            foreach ($DC in $DomainControllers) {
                $DCCounter++
                Write-Progress -Activity "Checking domain controllers" -Status "Processing $($DC.HostName)" -PercentComplete (($DCCounter / $DomainControllers.Count) * 100)

                Try {
                    $UserInfo = Get-ADUser -Identity $Identity -Server $DC.HostName -Properties AccountLockoutTime, LastBadPasswordAttempt, BadPwdCount, LockedOut -ErrorAction Stop
                } Catch {
                    Write-Warning "Failed to get user info from $($DC.HostName): $_"
                    Continue
                }

                if ($UserInfo.LastBadPasswordAttempt) {
                    $LockedOutStats += [PSCustomObject]@{
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

            $LockedOutStats | Format-Table -Property Name, LockedOut, DomainController, BadPwdCount, AccountLockoutTime, LastBadPasswordAttempt -AutoSize
        }

        End {
            Write-Host "Search completed." -ForegroundColor Cyan
        }
    }

    # Example usage:
    # Test-LockedOutLocation -Identity "mao-de"