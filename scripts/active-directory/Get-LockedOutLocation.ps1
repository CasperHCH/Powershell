#Requires -Version 2.0

#Function Get-LockedOutLocation
#{
<#
.SYNOPSIS
	This function will locate the computer that processed a failed user logon attempt which caused the user account to become locked out.

.DESCRIPTION
	This function will locate the computer that processed a failed user logon attempt which caused the user account to become locked out.
	The locked out location is found by querying the PDC Emulator for locked out events (4740).
	The function will display the BadPasswordTime attribute on all of the domain controllers to add in further troubleshooting.

.EXAMPLE
	PS C:\>Get-LockedOutLocation mao-de


	This example will find the locked out location for Manuel Orlitzky.
.NOTE
	This function is only compatible with an environment where the domain controller with the PDCe role to be running Windows Server 2008 SP2 and up.
	The script is also dependent the ActiveDirectory PowerShell module, which requires the AD Web services to be running on at least one domain controller.
	Last Modified: 15/08/2017
#>
    [CmdletBinding()]

    Param(
      [Parameter(Mandatory=$True)]
      [ValidateNotNullOrEmpty()]
      [string]$Identity
    )

    Begin
    {
        $DCCounter = 0
        $LockedOutStats = @()

        Try
        {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        Catch
        {
           Write-Warning $_
           Break
        }
    }#end begin
    Process
    {
      #Get all domain controllers in domain
      $DomainControllers = Get-ADDomainController -Filter *
      $PDCEmulator = ($DomainControllers | Where-Object { $_.OperationMasterRoles -and ($_.OperationMasterRoles -contains "PDCEmulator") })

      Write-Verbose "Found PDC Emulator: $($PDCEmulator.HostName)"
      $targetUserSid = $null

      Foreach($DC in $DomainControllers)
      {
        $DCCounter++
        Write-Progress -Activity "Checking Domain Controllers" -Status "Processing $($DC.HostName)" -PercentComplete (($DCCounter/$DomainControllers.Count) * 100)
        Try
        {
          $UserInfo = Get-ADUser -Identity $Identity  -Server $DC.Hostname -Properties AccountLockoutTime,LastBadPasswordAttempt,BadPwdCount,LockedOut -ErrorAction Stop
        }
        Catch
        {
          Write-Warning $_
          Continue
        }
        if (-not $targetUserSid) {
          $targetUserSid = $UserInfo.SID.Value
        }

        If($UserInfo.LastBadPasswordAttempt)
        {
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
        }#end if
      }#end foreach DCs
      $LockedOutStats | Format-Table -Property Name,LockedOut,DomainController,BadPwdCount,AccountLockoutTime,LastBadPasswordAttempt -AutoSize

      #Get User Info
      Try
      {
        Write-Verbose "Checking for lockout events on PDC Emulator: $($PDCEmulator.HostName)"
        $LockedOutEvents = Get-WinEvent -ComputerName $PDCEmulator.HostName -FilterHashtable @{LogName='Security';Id=4740} -ErrorAction Stop | Sort-Object -Property TimeCreated -Descending
      }
      Catch
      {
        Write-Warning $_
        Continue
      }#end catch

      Foreach($LockedOutEvent in $LockedOutEvents)
      {
        If($targetUserSid -and ($LockedOutEvent | Where-Object {$_.Properties[2].Value -match $targetUserSid}))
        {

          $LockedOutEvent | Select-Object -Property @(
            @{Label = 'User';               Expression = {$_.Properties[0].Value}}
            @{Label = 'DomainController';   Expression = {$_.MachineName}}
            @{Label = 'EventId';            Expression = {$_.Id}}
            @{Label = 'LockedOutTimeStamp'; Expression = {$_.TimeCreated}}
            @{Label = 'Message';            Expression = {$_.Message -split "`r`n" | Select-Object -First 1}}
            @{Label = 'LockedOutLocation';  Expression = {$_.Properties[1].Value}}
          )

        }#end ifevent

      }#end foreach lockedout event

    }#end process

#}#end function
#Get-LockedOutLocation
