<#
.SYNOPSIS
	This script searches for the most recent instances of Lync Server warnings 31137 & 31138 (RGS Agents not enabled for UC or EV)
	and identifies the Agent Groups to which they belong. Command-line switches provide options for the user to effortlessly
	correct the situation.

.DESCRIPTION
	This script searches for the most recent instances of Lync Server warnings 31137 & 31138 (RGS Agents not enabled for UC or EV)
	and identifies the Agent Groups to which they belong. If a user still exists on the system but is Disabled for Enterprise
	Voice, the  switch will re-enable Enterprise Voice. If a user is no longer present in Lync (and presumably no longer
	in AD) the  switch will remove them from all Groups. If someone else has already corrected the warnings reported in
	these events, the  and  switches will have no effect.

.NOTES
    Version				: 1.3
	Date				: 29th May 2016
	Author    			: Greig Sheridan
	There are lots of credits at the bottom of the script

	Revision History:
	v1.3 29May 2016		: Corrected bug where invalid agents in Distribution Group resulted in the group being replaced by the list of remaining (good) agents
						  Added code-signing certificate. (Thank you DigiCert)
						  Added  to suppress warning messages showing on screen if the user has unrelated config issues
						  Removed 'width' values from $myFormatShow & replaced with  to improve legibility on-screen
						  Added DistributionGroup as a new member to the output object
						  Changed the output object to always show Action and DistributionGroup
						  Changed command tests to try/catch blocks for improved error handling
						  Added ProgressBar to provide a visual indication as it's reading the users returned from the event logs
						  Changed the way the Agent Groups are read - now only once, rather than repeatedly for each nominated user

	v1.2 13Sept2013		: Updated the conjoining of events 31137 & 31138 to correctly capture multiple agents (Tks again Chris)
	v1.1 08Sept2013		: Corrected bug where Event31138 entries were over-writing those of 31137. (Thanks Chris!)
	v1.0 22Aug2013	 	: Initial release.


.LINK
    https://greiginsydney.com/Get-InvalidRgsAgents.ps1

.EXAMPLE
	.\Get-InvalidRgsAgents.ps1

	Description
	-----------
    Searches the Lync error log for the most recent instance of Lync Server warnings 31137 & 31138 (). The users named are then passed to Get-CsRgsAgentGroup to identify the groups
	they belong to & this output is written to the screen. If you have Response Groups across multiple pools, all are tested,
	however ONLY users homed to the local Front-End will be identified in that machine's event log.


.EXAMPLE
	.\Get-InvalidRgsAgents.ps1 -restore

	Description
	-----------
	Reads the event log and identifies agent groups, then re-enables for EV any non-EV user that still exists on the system. Other
	users are not changed.

.EXAMPLE
	.\Get-InvalidRgsAgents.ps1 -remove

	Description
	-----------
	Reads the event log and identifies agent groups, then deletes the agents from the groups. The script won't touch any users
	that have already been corrected (i.e presumably by someone else - the event entry might not reflect the current state).


.PARAMETER Restore
		Boolean. If $True (or simply present), any agents that are EV disabled will be re-enabled. Use of the
		parameter  is mutually exclusive - the script will abort if both are specified.

.PARAMETER Remove
		Boolean. If $True (or simply present), any agents not reporting as  will be removed from the group. If the group's agents
		are populated from a Distribution Group the script will make no change and instead report the group's e-mail address so you can
		manually remove them. Use of the parameter  is mutually exclusive - the script will abort if both are specified.


#>

[CmdletBinding(DefaultParameterSetName = )]
param(
	[parameter(
		mandatory=$false,
		parametersetname=
	)]
		[switch]$Restore,

	[parameter(
		mandatory=$false,
		parametersetname=
	)]
		[switch]$Remove
)

$Error.Clear()          #Clear PowerShell's error variable


#--------------------------------
# START MAIN CODE EXECUTION -----
#--------------------------------

write-progress -id 1 -Activity  -Status
if(-not(Get-Module -name ActiveDirectory)){Import-Module ActiveDirectory}

write-progress -id 1 -Activity  -Status
$Event31137 = Get-EventLog  | ? {$_.eventid -eq 31137} | Select Message -First 1
$users31137 = $Event31137 | select-string -pattern   -AllMatches | %{ $_.Matches } | %{ $_.Value }

write-progress -id 1 -Activity  -Status
$Event31138 = Get-EventLog  | ? {$_.eventid -eq 31138} | Select Message -First 1
$users31138 = $Event31138 | select-string -pattern   -AllMatches | %{ $_.Matches } | %{ $_.Value }
write-progress -id 1 -Activity  -Status  -Completed

$users = @()
if ($users31137.count -ne 0) {$users  += $users31137.Split(' ')}
if ($users31138.count -ne 0) {$users  += $users31138.Split(' ')}

$users = $users | select -uniq #Remove dupes

$Grouptable = @()
$status =
$action =

write-progress -id 1 -Activity  -Status
$AllGroups = Get-CsRgsAgentGroup
write-progress -id 1 -Activity  -Status

foreach ($user in $users)
{
	write-progress -id 1 -Activity  -Status
	if ($thisUser = get-csuser -Identity  -ea silentlyContinue -wa silentlyContinue)
	{
		#OK, they're in Lync.
		if ($thisUser.EnterpriseVoiceEnabled -eq $false)
		{
			$status =
		}
		else
		{
			$status =  	#Someone else must have already fixed them up prior to the script running
		}
	}
	else
	{
		$status =
	}

	$Groups = $AllGroups | where {$_.agentsbyuri -contains }
	foreach ($Group in $groups)
	{
		$DG =  $group.DistributionGroupAddress
		$action =
		if ($Restore)
		{
			if  ($status -eq )
			{
				try
				{
					set-csuser -Identity  -EnterpriseVoiceEnabled $true -AudioVideoDisabled $false -wa silentlyContinue
					$action =
				}
				catch
				{
					#$_ | fl * -f
					$action =
				}
			}
			else
			{
				$action =
			}
		}
		if ($Remove)
		{
			if ($status -ne )
			{
				if ($group.DistributionGroupAddress -eq $null)
				{
					$Group.AgentsByUri.Remove() | Out-Null
					try
					{
						Set-CsRgsAgentGroup -Instance $Group
						$action =
					}
					catch
					{
						$_ | fl * -f
						$action =
					}
				}
				else
				{
					$action =
				}
			}
			else
			{
				$action =
			}
		}
		#Now create a custom object so we can output all this into a table:
		$Properties  = @{User = $user; Group = $Group.Name; Owner = $Group.OwnerPool; Status = $status; Action = $action; DistributionGroup = $DG}
		$TableRow = new-object PSObject -Property $Properties
		$GroupTable += $TableRow
	}
}
$myFormatShow = @{Expression={$_.User};Label="User"}, `
			@{Expression={$_.Group};Label="Group"}, `
			@{Expression={$_.Owner};Label="Owner"}, `
			@{Expression={$_.Status};Label="Status"}, `
			@{Expression={$_.Action};Label="Action"}, `
			@{Expression={$_.DistributionGroup};Label="DistributionGroup"}
$GroupTable | format-table $myFormatShow -auto


# With thanks to:
#Reading from the event log: https://greiginsydney.com/trawling-exchanges-application-event-logs-using-powershell/
#Reading from the event log MUCH FASTER: THANK YOU PAT RICHARD! http://lync.ideascale.com/a/dtd/GUI-and-PS-command-to-see-who-is-federating-with-me/506570-16285
#Step Back in Time: http://blogs.msdn.com/b/powershell/archive/2006/09/17/the-wonders-of-date-math-using-windows-powershell.aspx
#Reading agent group membership: http://social.technet.microsoft.com/Forums/lync/en-US/bea63bc0-fdd9-4219-af4e-f4b5846e3b9a/powershell-agent-groups-membership
#Creating custom object:
#	1) http://powershell.com/cs/forums/p/7751/12634.aspx
#	2) http://exchangeserverpro.com/forums/powershell-corner/139-powershell-combining-results-two-cmdlets.html
#Creating custom tables: http://technet.microsoft.com/en-us/library/ee692794.aspx
#Removing agents from a group: http://blogs.technet.com/b/nexthop/archive/2011/07/13/agmanagingresponsegroups.aspx

# Code signing certificate with thanks to DigiCert:
# SIG # Begin signature block
# MIIceAYJKoZIhvcNAQcCoIIcaTCCHGUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUHUJS8qAdj1YjmKpBNgVMhfrq
# wF2gghenMIIFMDCCBBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0B
# AQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# Q29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# +NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPApfmJ
# 1DcZ17aq8JyGpdglrA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0
# sSgmuyRpwsJS8hRniolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6s
# cKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4Tz
# rGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg
# 0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYBBQUH
# AQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYI
# KwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaG
# NGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwTwYDVR0gBEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0
# dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYE
# FFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1dHC06
# GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/cY5j
# DhNLrddfRHnzNhQGivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6cSgC
# PC6Ro8AlEeKcFEehemhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwlCEIy
# sjaKJAL+L3J+HNdJRZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4Gb
# T8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIFMDCC
# BBigAwIBAgIQB4+827Fs8hYxNWap8+Z/LDANBgkqhkiG9w0BAQsFADByMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBMB4XDTE1MTIyODAwMDAwMFoXDTE3MDMyNDEyMDAwMFowbTEL
# MAkGA1UEBhMCQVUxGDAWBgNVBAgTD05ldyBTb3V0aCBXYWxlczESMBAGA1UEBxMJ
# UGV0ZXJzaGFtMRcwFQYDVQQKEw5HcmVpZyBTaGVyaWRhbjEXMBUGA1UEAxMOR3Jl
# aWcgU2hlcmlkYW4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC4MJ+t
# lY8wwvj+tD7Rj8zOZOVlc8iYBwI4S4dzy869ACUEXyjDwuxRY1VrjMyXAUjAy041
# Xu6YlADJVJpHIaKd0asRTJo63z9fr1+RwJeP3ekmLl0lKIfFanhmh6kprDVWcxxz
# W/ZQoOgjrQvQPGfymNl3xVkfR0LUAINQM9US+/XgGfYXeJk8CCcskYGFcuPtvcDU
# dpUUn8Xpt7iSILoZ7GwQ9dHY9tkDq7j6U8fNymVF1FyrMSERLyGyHpZSm6KA0vtp
# qYg3aTxSKsvjDFtvhi2ba5yWVNEvD1r2zmX8pDauIrYajkEWYVFqCfKTlLPCxVQ7
# jbSpBCHCP8lKks89AgMBAAGjggHFMIIBwTAfBgNVHSMEGDAWgBRaxLl7Kgqjpepx
# A8Bg+S32ZXUOWDAdBgNVHQ4EFgQUCXq15BdUVo3nQbWr/4vwn4vY94QwDgYDVR0P
# AQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGG
# L2h0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3Js
# MDWgM6Axhi9odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNz
# LWcxLmNybDBMBgNVHSAERTBDMDcGCWCGSAGG/WwDATAqMCgGCCsGAQUFBwIBFhxo
# dHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUH
# AQEEeDB2MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYI
# KwYBBQUHMAKGQmh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNI
# QTJBc3N1cmVkSURDb2RlU2lnbmluZ0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqG
# SIb3DQEBCwUAA4IBAQAcm+5S/troPk5MVo/KyuTl06+CCIK3NZ7WFPsLkkK3+wAH
# Ar7vWFcpIKvetJC8vb6FgXGag/3naFcO+iJTf8EQt11mS2PEp8k7JHu8bG/qEP6+
# DfJI+cf6/rvwouHUh/uChUVyb55ZEIGQG2ItjD7NGWeh33TCjIEp+pgk3l2j9q32
# SAAWUGSv4VExhn2tDqe0DRy20JkB1yHnWuLGRdVJBTt0oyh84QKzO9SSqwvNfoaZ
# LdMVAePn3yghJra4BYbgfeMs/V4GYd0KMqDkYVDWxQJoyOYA39LkQp7DS9813w+q
# l+BtW6AgeSudk/+/QuPSRMymZqn/krUfiPqVKeHCMIIGajCCBVKgAwIBAgIQAwGa
# Ajr/WLFr1tXq5hfwZjANBgkqhkiG9w0BAQUFADBiMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEw
# HwYDVQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTEwHhcNMTQxMDIyMDAwMDAw
# WhcNMjQxMDIyMDAwMDAwWjBHMQswCQYDVQQGEwJVUzERMA8GA1UEChMIRGlnaUNl
# cnQxJTAjBgNVBAMTHERpZ2lDZXJ0IFRpbWVzdGFtcCBSZXNwb25kZXIwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCjZF38fLPggjXg4PbGKuZJdTvMbuBT
# qZ8fZFnmfGt/a4ydVfiS457VWmNbAklQ2YPOb2bu3cuF6V+l+dSHdIhEOxnJ5fWR
# n8YUOawk6qhLLJGJzF4o9GS2ULf1ErNzlgpno75hn67z/RJ4dQ6mWxT9RSOOhkRV
# fRiGBYxVh3lIRvfKDo2n3k5f4qi2LVkCYYhhchhoubh87ubnNC8xd4EwH7s2AY3v
# J+P3mvBMMWSN4+v6GYeofs/sjAw2W3rBerh4x8kGLkYQyI3oBGDbvHN0+k7Y/qpA
# 8bLOcEaD6dpAoVk62RUJV5lWMJPzyWHM0AjMa+xiQpGsAsDvpPCJEY93AgMBAAGj
# ggM1MIIDMTAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDCCAb8GA1UdIASCAbYwggGyMIIBoQYJYIZIAYb9bAcBMIIB
# kjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzCCAWQG
# CCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMA
# IABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMA
# IABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMA
# ZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkA
# bgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgA
# IABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUA
# IABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAA
# cgBlAGYAZQByAGUAbgBjAGUALjALBglghkgBhv1sAxUwHwYDVR0jBBgwFoAUFQAS
# KxOYspkH7R7for5XDStnAs0wHQYDVR0OBBYEFGFaTSS2STKdSip5GoNL9B6Jwcp9
# MH0GA1UdHwR2MHQwOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRENBLTEuY3JsMDigNqA0hjJodHRwOi8vY3JsNC5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRBc3N1cmVkSURDQS0xLmNybDB3BggrBgEFBQcBAQRrMGkw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcw
# AoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Q0EtMS5jcnQwDQYJKoZIhvcNAQEFBQADggEBAJ0lfhszTbImgVybhs4jIA+Ah+WI
# //+x1GosMe06FxlxF82pG7xaFjkAneNshORaQPveBgGMN/qbsZ0kfv4gpFetW7ea
# sGAm6mlXIV00Lx9xsIOUGQVrNZAQoHuXx/Y/5+IRQaa9YtnwJz04HShvOlIJ8Oxw
# YtNiS7Dgc6aSwNOOMdgv420XEwbu5AO2FKvzj0OncZ0h3RTKFV2SQdr5D4HRmXQN
# JsQOfxu19aDxxncGKBXp2JPlVRbwuwqrHNtcSCdmyKOLChzlldquxC5ZoGHd2vNt
# omHpigtt7BIYvfdVVEADkitrwlHCCkivsNRu4PQUCjob4489yq9qjXvc2EQwggbN
# MIIFtaADAgECAhAG/fkDlgOt6gAK6z8nu7obMA0GCSqGSIb3DQEBBQUAMGUxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBD
# QTAeFw0wNjExMTAwMDAwMDBaFw0yMTExMTAwMDAwMDBaMGIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAOiCLZn5ysJClaWAc0Bw0p5WVFypxNJBBo/J
# M/xNRZFcgZ/tLJz4FlnfnrUkFcKYubR3SdyJxArar8tea+2tsHEx6886QAxGTZPs
# i3o2CAOrDDT+GEmC/sfHMUiAfB6iD5IOUMnGh+s2P9gww/+m9/uizW9zI/6sVgWQ
# 8DIhFonGcIj5BZd9o8dD3QLoOz3tsUGj7T++25VIxO4es/K8DCuZ0MZdEkKB4YNu
# gnM/JksUkK5ZZgrEjb7SzgaurYRvSISbT0C58Uzyr5j79s5AXVz2qPEvr+yJIvJr
# GGWxwXOt1/HYzx4KdFxCuGh+t9V3CidWfA9ipD8yFGCV/QcEogkCAwEAAaOCA3ow
# ggN2MA4GA1UdDwEB/wQEAwIBhjA7BgNVHSUENDAyBggrBgEFBQcDAQYIKwYBBQUH
# AwIGCCsGAQUFBwMDBggrBgEFBQcDBAYIKwYBBQUHAwgwggHSBgNVHSAEggHJMIIB
# xTCCAbQGCmCGSAGG/WwAAQQwggGkMDoGCCsGAQUFBwIBFi5odHRwOi8vd3d3LmRp
# Z2ljZXJ0LmNvbS9zc2wtY3BzLXJlcG9zaXRvcnkuaHRtMIIBZAYIKwYBBQUHAgIw
# ggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQByAHQA
# aQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBjAGUA
# cAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAgAEMA
# UAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQAGEA
# cgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBtAGkA
# dAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBjAG8A
# cgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBlAHIA
# ZQBuAGMAZQAuMAsGCWCGSAGG/WwDFTASBgNVHRMBAf8ECDAGAQH/AgEAMHkGCCsG
# AQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8v
# Y3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqg
# OKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3JsMB0GA1UdDgQWBBQVABIrE5iymQftHt+ivlcNK2cCzTAfBgNVHSME
# GDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEARlA+
# ybcoJKc4HbZbKa9Sz1LpMUerVlx71Q0LQbPv7HUfdDjyslxhopyVw1Dkgrkj0bo6
# hnKtOHisdV0XFzRyR4WUVtHruzaEd8wkpfMEGVWp5+Pnq2LN+4stkMLA0rWUvV5P
# sQXSDj0aqRRbpoYxYqioM+SbOafE9c4deHaUJXPkKqvPnHZL7V/CSxbkS3BMAIke
# /MV5vEwSV/5f4R68Al2o/vsHOE8Nxl2RuQ9nRc3Wg+3nkg2NsWmMT/tZ4CMP0qqu
# AHzunEIOz5HXJ7cW7g/DvXwKoO4sCFWFIrjrGBpN/CohrUkxg0eVd3HcsRtLSxwQ
# nHcUwZ1PL1qVCCkQJjGCBDswggQ3AgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAv
# BgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EC
# EAePvNuxbPIWMTVmqfPmfywwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAI
# oAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIB
# CzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFGwUHAexecvc4Z7u8/Jf
# rjR7QKVNMA0GCSqGSIb3DQEBAQUABIIBAAs8R7UC0EBHUHVJU6qVAKX4JDLgEdDr
# Ey36qEMb1NLY80nGTIs7bSFrGzSBiVRqV6wB8bvnbyDJRn5jqxUfH0E92hFLSbcC
# Vn6s4LQBOlgfCtgIu2Gom8NF/B/9NJMZDxS4ykR88z63JC/tYsL31ZYETpaDKpJ0
# izNgn8VEVu78lfcV1thj0NQuj4V0HJ4dz0dHoL8MTzHr4K7visGnGB4VcGyR+Nwj
# 0dQfZ5c+eBFJjiUqdQULVj+fQULQsmWIreEGnmaLeVISs1qGjANXyjqzlR6zGHpv
# mZMuhhqBTfCLUg3kyPtOAN6vKVJd9dQNd2ab1rtMw2hWoPxSAVDgZGGhggIPMIIC
# CwYJKoZIhvcNAQkGMYIB/DCCAfgCAQEwdjBiMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYD
# VQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTECEAMBmgI6/1ixa9bV6uYX8GYw
# CQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcN
# AQkFMQ8XDTE2MDUyOTA2MDk0NlowIwYJKoZIhvcNAQkEMRYEFIpeqIVIzQyJWEAo
# z0vMyyrWdp4bMA0GCSqGSIb3DQEBAQUABIIBAClvi+H3W8VlfZxIbwieU2tnpIxt
# IST1+DZdds8viz3niueBxYnF0FCbevXHpv6XfCeddZz9KSQJ48gDtlLeLScIXFzy
# cTHMG2dxditG/r7KL71mjL2gt+1SlbaMZqdzyJzIm1o6idGi1xoM6ubpPQE92qV+
# +pFGBI3Ph/Sqz8uy8souYA7kaNVvESgNQ/Vw1VLhASqCUwDy/04li+SOh94zC7dV
# yoQX6zCjwxXWU/kH1iJgvrCkei2dBo1aoMIJFJgklyBRik8fryOgSzAniSq2tied
# X10TEWri7DPG2PXPpfU4//MhRhmazshQJCu72W5gE0Xn1nbGS85P80dtMmU=
# SIG # End signature block
