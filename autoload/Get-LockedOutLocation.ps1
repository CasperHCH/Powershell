#Requires -Version 2.0
Function Get-LockedOutLocation {
    <#
    .SYNOPSIS
        This function will locate the computer, unit, or device that processed a failed user logon attempt which caused the user account to become locked out.
    .DESCRIPTION
        This function will locate the computer, unit, or device that processed a failed user logon attempt which caused the user account to become locked out.
        The locked out location is found by querying the PDC Emulator for locked out events (4740).
        The function will display the BadPasswordTime attribute on all of the domain controllers to add in further troubleshooting.
    .EXAMPLE
        PS C:\>Get-LockedOutLocation -Identity "mao-de"
        This example will find the locked out location for Manuel Orlitzky.
    .NOTES
        This function is only compatible with an environment where the domain controller(s) with the PDCe role are running Windows Server 2008 SP2 and up.
        The script is also dependent on the ActiveDirectory PowerShell module, which requires the AD Web services to be running on at least one domain controller.
        Last Modified: 20/02/2018
    #>
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true, HelpMessage = "Specify the user identity.")]
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
            $DomainControllers = Get-ADDomainController -Filter {IsReadOnly -eq $false}
            $PDCEmulator = ($DomainControllers | Where-Object {$_.OperationMasterRoles -contains "PDCEmulator"})

            Write-Verbose "Found $($DomainControllers.Count) domain controllers."

            foreach ($DC in $DomainControllers) {
                $DCCounter++
                Write-Progress -Activity "Checking domain controllers" -Status "Processing $($DC.HostName)" -PercentComplete (($DCCounter / $DomainControllers.Count) * 100)

                Try {
                    $UserInfo = Get-ADUser -Identity $Identity -Server $DC.Hostname -Properties AccountLockoutTime, LastBadPasswordAttempt, BadPwdCount, LockedOut -ErrorAction Stop
                } Catch {
                    Write-Warning "Failed to get user info from $($DC.Hostname): $_"
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

            # Get User Info
            Try {
                Write-Verbose "Querying PDC Emulator for locked out events."
                $LockedOutEvents = Get-WinEvent -ComputerName $PDCEmulator.HostName -FilterHashtable @{LogName='Security';Id=4740} -ErrorAction Stop | Sort-Object -Property TimeCreated -Descending
            } Catch {
                Write-Warning "Failed to get locked out events from PDC Emulator: $_"
                Continue
            }

            foreach ($Event in $LockedOutEvents) {
                if ($Event | Where-Object { $_.Properties[2].Value -match $UserInfo.SID.Value }) {
                    $Event | Select-Object -Property @(
                        @{Label = 'User';               Expression = { $_.Properties[0].Value }}
                        @{Label = 'DomainController';   Expression = { $_.MachineName }}
                        @{Label = 'EventId';            Expression = { $_.Id }}
                        @{Label = 'LockedOutTimeStamp'; Expression = { $_.TimeCreated }}
                        @{Label = 'Message';            Expression = { ($_.Message -split "`n") | Select-Object -First 1 }}
                        @{Label = 'LockedOutLocation';  Expression = { $_.Properties[1].Value }}
                    )
                }
            }
        }
    }

    # Example usage:
    # Get-LockedOutLocation -Identity "mao-de"