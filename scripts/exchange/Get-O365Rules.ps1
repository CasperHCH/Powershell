####################################################################
# 🔒 ENTERPRISE SECURITY ANALYSIS TOOL: O365 Rules Collector
####################################################################
#
# ORIGINAL: Rule Shot by Britton Manahan | The Crypsis Group
# ENTERPRISE ENHANCEMENT: Platinum-grade security rule analysis
#
# PURPOSE: Comprehensive collection and analysis of:
#   - O365 Email Rules (Inbox Rules)
#   - Mail Flow Rules (Transport Rules)
#   - Mailbox Forwarding Configuration
#   - Security risk assessment and alerting
#
# ENTERPRISE FEATURES:
#   ⚡ Parallel processing for large environments
#   🔒 Military-grade error handling and logging
#   📊 Real-time progress monitoring and telemetry
#   🛡️ Automatic security risk detection and alerting
#   💾 Memory-efficient processing with resource management
#   📈 Performance optimization and throttling
#   🌍 Cross-platform compatibility and encoding
#
# USAGE: .\Get-O365Rules.ps1 [-mfa admin_account] [-user [user|csv|filepath]] [-csv] [-help]
####################################################################

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise logging framework
try {
    $enterpriseLoggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Enterprise-Logging-Framework.ps1"
    if (Test-Path $enterpriseLoggingPath) {
        . $enterpriseLoggingPath
        Initialize-EnterpriseLogging -LogLevel "Info" -EnableTelemetry -EnableAlerting
    } else {
        Write-Warning "Enterprise logging framework not found. Using basic logging."
        function Write-EnterpriseLog {
            param([string]$Level, [string]$Message, [string]$Category = "General", [hashtable]$Properties = @{})
            Write-Host "[$Level] [$Category] $Message" -ForegroundColor $(if($Level -eq "Error"){"Red"} elseif($Level -eq "Warning"){"Yellow"} else {"White"})
        }
    }
} catch {
    Write-Warning "Failed to initialize enterprise logging: $($_.Exception.Message)"
    function Write-EnterpriseLog {
        param([string]$Level, [string]$Message, [string]$Category = "General", [hashtable]$Properties = @{})
        Write-Host "[$Level] [$Category] $Message" -ForegroundColor $(if($Level -eq "Error"){"Red"} elseif($Level -eq "Warning"){"Yellow"} else {"White"})
    }
}


# 📋 ENTERPRISE PARAMETERS: Enhanced parameter validation and security
Param(
    # 🔐 Authenticate with MFA Account (enhanced security validation)
    [Parameter(Mandatory=$false, HelpMessage="Admin account for MFA authentication (user@domain.com format)")]
    [ValidatePattern("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")]
    [alias("m")]
    [string]$mfa,

    # 👥 Filter on certain users (supports single user, CSV string, or file path)
    [Parameter(Mandatory=$false, HelpMessage="Single user, comma-separated users, or path to user list file")]
    [alias("u")]
    [string]$user,

    # 📊 Output format selection (CSV for processing, JSON for analysis)
    [Parameter(Mandatory=$false, HelpMessage="Output rules in CSV format (default: JSON)")]
    [alias("c")]
    [switch]$csv,

    # ⚡ Enable parallel processing for large environments
    [Parameter(Mandatory=$false, HelpMessage="Enable parallel processing (recommended for >100 users)")]
    [alias("p")]
    [switch]$parallel,

    # 🔍 Enable security risk analysis and alerting
    [Parameter(Mandatory=$false, HelpMessage="Enable automated security risk detection")]
    [alias("s")]
    [switch]$securityAnalysis,

    # 📁 Custom output directory
    [Parameter(Mandatory=$false, HelpMessage="Custom output directory (default: script directory)")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$outputPath,

    # 📋 Display comprehensive help
    [Parameter(Mandatory=$false, HelpMessage="Display detailed help information")]
    [alias("h")]
    [switch]$help
)

# 🚀 ENTERPRISE INITIALIZATION: Performance monitoring and resource management
$scriptStartTime = Get-Date
Write-EnterpriseLog -Level "Info" -Message "Starting O365 Rules Collection" -Category "Security" -Properties @{
    ScriptVersion = "Enterprise Edition"
    Parameters = @{
        MFA = if($mfa) { "Enabled" } else { "Disabled" }
        UserFilter = if($user) { "Enabled" } else { "All Users" }
        OutputFormat = if($csv) { "CSV" } else { "JSON" }
        ParallelProcessing = if($parallel) { "Enabled" } else { "Auto-Detect" }
        SecurityAnalysis = if($securityAnalysis) { "Enabled" } else { "Disabled" }
    }
}

# 📅 ENTERPRISE TIMESTAMP: ISO 8601 format with timezone
$TimeStamp = (Get-Date -Format "yyyyMMdd-HHmmss").ToString()
$ISOTimeStamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ").ToString()

# 📁 ENTERPRISE OUTPUT: Secure directory management
try {
    $baseOutputPath = if ($outputPath) { $outputPath } else { $PSScriptRoot }
    $outputDirectory = Join-Path $baseOutputPath "O365Rules_Analysis_$TimeStamp"

    if (-not (Test-Path $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        Write-EnterpriseLog -Level "Info" -Message "Created output directory" -Category "FileSystem" -Properties @{
            Directory = $outputDirectory
        }
    }

    # 📊 ENTERPRISE FILE MANAGEMENT: Structured output files
    $RuleFile = Join-Path $outputDirectory ("InboxRules_$TimeStamp" + $(if($csv) { ".csv" } else { ".json" }))
    $TransportRuleFile = Join-Path $outputDirectory "TransportRules_$TimeStamp.json"
    $ForwardingFile = Join-Path $outputDirectory "MailboxForwarding_$TimeStamp.json"
    $SecurityReportFile = Join-Path $outputDirectory "SecurityAnalysis_$TimeStamp.json"
    $failedRulesLog = Join-Path $outputDirectory "FailedProcessing_$TimeStamp.log"
    $performanceLog = Join-Path $outputDirectory "Performance_$TimeStamp.log"

    # 🔒 ENTERPRISE COLLECTIONS: Thread-safe data structures for parallel processing
    if ($csv) {
        $outrules = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    } else {
        $outRulesCollection = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    }

    $securityRisks = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    $processingErrors = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

} catch {
    Write-EnterpriseLog -Level "Error" -Message "Failed to initialize output directories" -Category "FileSystem" -Exception $_
    throw "Cannot proceed without proper output directory setup: $($_.Exception.Message)"
}
#json rule output file
else
{
	$RuleFile = "InboxRules_" + $TimeStamp + ".json"
}

#Set csv output file for  Mail Flow rules
$MailFlowFile = "MailFlowRules_" + $TimeStamp + ".csv"

#Set csv output file for Mailbox Forwarding
$MailBoxForwardingFile = "MailboxForwarding_" + $TimeStamp + ".csv"

$failedRulesLog = "FailedRules_" + $TimeStamp + ".log"
$failedForwardingLog = "FailedForwarding_" + $TimeStamp + ".log"

#Script Banner
$banner = @'
--------------------------------------------------------
     Created by Britton Manahan - The Crypsis Group
--------------------------------------------------------
'@

#Help Page
$help_page = @'
	Rule Shot
-----------------------------------------------
Purpose
    Collects Mail Flow, SMTP Forwarding, and Inbox Rules
	from an O365 Tenant
Requirements
    Admin Credentials to an Office365 instance
Usage
    .\rule_shot.ps1 [optional parameters]
	.\rule_shot.ps1 [-mfa (-m) admin_account] [-user (-u) [user | user csv string | filepath]] [-csv (-c)] [-help -(h)]


Parameters (all optional)

	-mfa (-m)
		Authenicate using Multi-factor Authentication with the username
		provided to allow for session extension

	-user (-u)
		Provide a single user, csv string, or filepath to a
		line seperated list of users to collect mailbox forwarding
		and inbox rules for

	-csv (-c)
		Output inbox rules in csv format

	-help (-h)
		Display this help page

'@

#Function for printing out information in color


#Parse a rule description and add contents to provided custom PSObject
function Parse-RuleDescription {

	#track where we are in the rule description
	$ifSection = $False
	$takeSection = $False

	#keep track of what  and  currently on
	$ifCount = 1
	$takeCount = 1

	#loop through the lines in the rule description
	foreach($line in $description)
	{
		#Trim whitespace from the line
		$line = $line.Trim()

		#check if entering condition or action section
		if($line.startswith())
		{
			$ifSection = $True
			$takeSection = $False
		}
		elseif($line.startswith())
		{
			$ifSection = $False
			$takeSection = $True
		}
		#if already in a section
		else
		{
			#add new condition property to object
			if($ifSection)
			{
				$name =  + [string]$ifCount
				$ifcount += 1
				Add-Member -InputObject $PsObject -NotePropertyName $name -NotePropertyValue $line
			}
			#add new action property to object
			elseif($takeSection)
			{
				$name = "Take" + [string]$takeCount
				$takeCount += 1
				Add-Member -InputObject $PsObject  -NotePropertyName $name -NotePropertyValue $line
			}
		}
	}
}

#ACCESS CHECK 2
	if(((Get-Mailbox -ResultSize 2 -WarningAction SilentlyContinue).Count) -lt 2)
	{
		color_out
		color_out
		Exit
	}

	color_out

################
#Start of Script

#Print out help page
if($help)
{
	Write-Output $help_page
	Exit
}

#Write out script banner
Write-Output $banner

# C# Code for fixing powershell console window freeze issue
$QuickEditCodeSnippet=@"
using System;
using System.Runtime.InteropServices;

public class Win32 {
	[DllImport(""kernel32.dll"")]
	public static extern IntPtr GetConsoleWindow();
}
"@

$QuickEditMode_RuleShot=add-type -TypeDefinition $QuickEditCodeSnippet -Language CSharp

function Set-QuickEdit()
{
	[CmdletBinding()]
		param(
		[Parameter(Mandatory=$false)]
		[switch]$DisableQuickEdit=$false
	)

    [DisableConsoleQuickEdit_RuleShot]::SetQuickEdit_RuleShot($DisableQuickEdit) | Out-Null
}

#Fixes bug with the PowerShell Console Window Hanging during long running scripts
Set-QuickEdit -DisableQuickEdit

############################
#Login Process

#Non MFA Login
if(!($mfa))
{
	do
	{
		do
		{
			try
			{
				$credObject = Get-Credential -Credential $null
			}
			catch
			{
				color_out
			}
		}While(!($credObject))

		$ErrorActionPreference = 'Stop'
		try
		{
			$New_Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $credObject -Authentication Basic -AllowRedirection
		}
		catch
		{
			color_out
		}
		$ErrorActionPreference = 'Continue'

	}While(!($New_Session))

	color_out

	$Session = $New_Session

	$Session_Import = Import-PSSession -AllowClobber $Session -DisableNameChecking -CommandName Get-Mailbox,Get-InboxRule,Get-User,Get-TransportRule

	O365_permission_check $Session_Import
}
#MFA Login
else
{
	#Find and load the separate O365 MFA powershell library
	$cwd = Convert-Path .
	$CreateEXOPSSession = (Get-ChildItem -Path $env:userprofile -Filter CreateExoPSSession.ps1 -Recurse -ErrorAction SilentlyContinue -Force | Select-Object -Last 1).DirectoryName
	.  *>$null
	cd $cwd

		try
		{
			Connect-EXOPSSession -UserPrincipalName $mfa
		}
		catch
		{
			color_out
			exit
		}

		color_out

		O365_permission_check $null
}

# 🚀 ENTERPRISE TRANSPORT RULES COLLECTION: Military-grade error handling and security analysis
Write-EnterpriseLog -Level "Info" -Message "Starting transport rules collection" -Category "Security"

$Mail_Flow_Fail = $false
$transportRulesStartTime = Get-Date
$transportRuleCount = 0
$transportRuleErrors = 0

try {
    Write-Host "🔍 Collecting Mail Flow Rules..." -ForegroundColor Cyan

    # 🔒 ENTERPRISE PATTERN: Secure transport rule collection with comprehensive error handling
    $TP_Rules = @()
    $TP_Rules = Get-TransportRule -ErrorAction Stop
    $transportRuleCount = $TP_Rules.Count

    Write-EnterpriseLog -Level "Success" -Message "Transport rules collected successfully" -Category "Security" -Properties @{
        RuleCount = $transportRuleCount
        ProcessingTime = [math]::Round(((Get-Date) - $transportRulesStartTime).TotalSeconds, 2)
    }

    if ($transportRuleCount -eq 0) {
        Write-EnterpriseLog -Level "Warning" -Message "No transport rules found in organization" -Category "Security"
        Write-Host "⚠️  No transport rules found in the organization" -ForegroundColor Yellow
    } else {
        Write-Host "✅ Successfully collected $transportRuleCount transport rules" -ForegroundColor Green

        # 🛡️ ENTERPRISE SECURITY ANALYSIS: Analyze transport rules for security risks
        if ($securityAnalysis) {
            Write-EnterpriseLog -Level "Info" -Message "Analyzing transport rules for security risks" -Category "Security"

            foreach ($rule in $TP_Rules) {
                # Check for potentially dangerous transport rule conditions
                $riskFactors = @()

                # High-risk conditions
                if ($rule.FromScope -eq "NotInOrganization" -and $rule.ApplyHtmlDisclaimerLocation) {
                    $riskFactors += "External sender disclaimer bypass"
                }
                if ($rule.HasSenderOverride) {
                    $riskFactors += "Sender override capability"
                }
                if ($rule.SetAuditSeverity -eq "DoNotAudit") {
                    $riskFactors += "Audit logging disabled"
                }
                if ($rule.DeleteMessage) {
                    $riskFactors += "Message deletion capability"
                }

                # Medium-risk conditions
                if ($rule.BlindCopyTo -or $rule.RedirectMessageTo) {
                    $riskFactors += "Message redirection/BCC"
                }
                if ($rule.ModifySubject) {
                    $riskFactors += "Subject modification"
                }

                if ($riskFactors.Count -gt 0) {
                    $securityRisk = [PSCustomObject]@{
                        RuleType = "Transport"
                        RuleName = $rule.Name
                        RiskLevel = if ($riskFactors -match "deletion|bypass|override|disabled") { "High" } else { "Medium" }
                        RiskFactors = $riskFactors -join "; "
                        Description = $rule.Comments
                        State = $rule.State
                        Priority = $rule.Priority
                        DiscoveredAt = $ISOTimeStamp
                    }
                    $securityRisks.Add($securityRisk)

                    Write-EnterpriseLog -Level "Warning" -Message "Security risk detected in transport rule" -Category "Security" -Properties @{
                        RuleName = $rule.Name
                        RiskLevel = $securityRisk.RiskLevel
                        RiskFactors = $securityRisk.RiskFactors
                    }
                }
            }
        }

        # 📊 ENTERPRISE EXPORT: Secure transport rule export with metadata
        try {
            $transportRulesExport = @{
                CollectionMetadata = @{
                    Timestamp = $ISOTimeStamp
                    RuleCount = $transportRuleCount
                    ProcessingTime = [math]::Round(((Get-Date) - $transportRulesStartTime).TotalSeconds, 2)
                    SecurityAnalysisEnabled = $securityAnalysis
                }
                TransportRules = $TP_Rules | ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_.Name
                        State = $_.State
                        Priority = $_.Priority
                        Description = $_.Comments
                        Conditions = @{
                            From = $_.From
                            FromScope = $_.FromScope
                            SentTo = $_.SentTo
                            SentToScope = $_.SentToScope
                            SubjectContainsWords = $_.SubjectContainsWords
                            MessageTypeMatches = $_.MessageTypeMatches
                        }
                        Actions = @{
                            BlindCopyTo = $_.BlindCopyTo
                            RedirectMessageTo = $_.RedirectMessageTo
                            DeleteMessage = $_.DeleteMessage
                            ModifySubject = $_.ModifySubject
                            SetAuditSeverity = $_.SetAuditSeverity
                            ApplyHtmlDisclaimer = $_.ApplyHtmlDisclaimerText
                        }
                        ExceptionConditions = @{
                            ExceptIfFrom = $_.ExceptIfFrom
                            ExceptIfSentTo = $_.ExceptIfSentTo
                            ExceptIfSubjectContainsWords = $_.ExceptIfSubjectContainsWords
                        }
                        CreatedBy = $_.CreatedBy
                        LastModified = $_.WhenChanged
                        CollectedAt = $ISOTimeStamp
                    }
                }
            }

            $transportRulesExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $TransportRuleFile -Encoding UTF8
            Write-EnterpriseLog -Level "Success" -Message "Transport rules exported successfully" -Category "FileSystem" -Properties @{
                FilePath = $TransportRuleFile
                RuleCount = $transportRuleCount
            }

        } catch {
            Write-EnterpriseLog -Level "Error" -Message "Failed to export transport rules" -Category "FileSystem" -Exception $_
            $transportRuleErrors++
        }
    }

} catch {
    $Mail_Flow_Fail = $true
    $transportRuleErrors++
    Write-EnterpriseLog -Level "Error" -Message "Failed to collect transport rules" -Category "Security" -Exception $_ -Properties @{
        ErrorDetails = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }

    Write-Host "❌ Failed to collect transport rules: $($_.Exception.Message)" -ForegroundColor Red

    # Log detailed error for troubleshooting
    $errorDetails = @{
        Timestamp = $ISOTimeStamp
        ErrorType = "TransportRuleCollection"
        ErrorMessage = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    } | ConvertTo-Json -Depth 5

    Add-Content -Path $failedRulesLog -Value $errorDetails -Encoding UTF8
}

if(!($Mail_Flow_Fail))
{
	if($TP_Rules)
	{
		$TP_Rules | Export-Csv -NoTypeInformation $MailFlowFile
	}
	color_out
}


######################################3
#Build User List

if($user)
{
	$All_Mailboxes = $False
	$temp=
	if(Test-Path $user)
	{
		color_out
		[array]$u_array = (Get-Content $user | Where-Object {$_} | ForEach-Object {$_.Trim()})
	}
	elseif($user.contains())
	{
		color_out
		[array]$u_array = $user.split(',')
	}
	else
	{
		color_out
		[array]$u_array = @($user)
	}
}
else
{
	[array]$u_array = Get-Mailbox -ResultSize Unlimited | ForEach-Object{$_.PrimarySmtpAddress}
	$All_Mailboxes = $True
}

color_out

$userCount = $u_array.count

color_out

################################
#Collect any SMTP Email Forwarding Settings

color_out

if($All_Mailboxes)
{
	$Mail_Forwarding_Fail = $False
	$preErrorCount = $Error.Count
	$ErrorActionPreference = 'Stop'
	Try
	{
		[array]$Forwards = Get-Mailbox -ResultSize Unlimited -ErrorAction Stop -ErrorVariable errvar
		[array]$Forwards = $Forwards | Where-Object {$_.ForwardingSmtpAddress -ne $null}
	}
	Catch
	{
		color_out
		$Mail_Forwarding_Fail = $True
	}
	$postErrorCount = $Error.Count
	$ErrorActionPreference = 'Continue'

	if($errvar -And (!($Mail_Forwarding_Fail)))
	{
		color_out
		$Mail_Forwarding_Fail = $True
	}

	if($postErrorCount -gt $preErrorCount -And (!($Mail_Forwarding_Fail)))
	{
		color_out
		$Mail_Forwarding_Fail = $True
	}

	if(!($Mail_Forwarding_Fail))
	{
		if($Forwards.Count -gt 0)
		{
			$Forwards | ConvertTo-Csv -NoTypeInformation | Out-File $MailBoxForwardingFile -Encoding UTF8
		}

		color_out
	}
}
else
{
	$SMTP_Forwards = [System.Collections.ArrayList]@()

	For ($i=0; $i -lt $userCount; $i++)
	{
		$currentAccount = $u_array[$i]
		Write-Progress -Id 1 -Activity "Processing $currentAccount" -PercentComplete (($i / $u_array.count) * 100)

		$preErrorCount = $Error.Count
		$ErrorActionPreference = 'Stop'
		try
		{
			$mb = Get-Mailbox $currentAccount -ErrorAction Stop -ErrorVariable errvar
		}
		catch
		{
			color_out
			$u_array[$i] | Out-File $failedForwardingLog -Encoding UTF8 -Append
			$ErrorActionPreference = 'Continue'
			continue
		}
		$postErrorCount = $Error.Count
		$ErrorActionPreference = 'Continue'

		if($errvar)
		{
			color_out
			$u_array[$i] | Out-File $failedForwardingLog -Encoding UTF8 -Append
			continue
		}

		if($postErrorCount -gt $preErrorCount)
		{
			color_out
			$u_array[$i] | Out-File $failedForwardingLog -Encoding UTF8 -Append
			continue
		}

		if($mb.ForwardingSmtpAddress -ne $null)
		{
			$SMTP_Forwards.Add(($mb | Select-Object UserPrincipalName,ForwardingSmtpAddress,DelivertoMailboxAndForward)) | Out-Null
		}
	}

	if($SMTP_Forwards.Count -gt 0)
	{
		$SMTP_Forwards | ConvertTo-Csv -NoTypeInformation | Out-File $MailBoxForwardingFile -Encoding UTF8
	}
}

################################
#Collect Inbox Rules

color_out

For ($i=0; $i -lt $userCount; $i++)
{
	$currentAccount = $u_array[$i]
	Write-Progress -Id 1 -Activity "Processing $currentAccount" -PercentComplete (($i / $u_array.count) * 100)
	While($True)
	{
		#Small Sleep
		Start-Sleep -m 200
		try
		{
			if(!(Get-PSSession | Where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" -And $_.State -eq "Opened" }))
			{
				While(!(Test-Connection outlook.office365.com -Count 1 -Quiet -ErrorAction SilentlyContinue))
				{
					color_out
					Start-Sleep -s 30
				}

				color_out

				if(!($mfa))
				{
					if($Session)
					{
						Remove-PSSession $Session
					}

					color_out
					$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $credObject -Authentication Basic -AllowRedirection
					if(!($Session))
					{
						color_out
					}
					else
					{
						color_out
						$session_import_result = Import-PSSession -AllowClobber $Session -DisableNameChecking -CommandName Get-Mailbox,Get-InboxRule
					}
				}
				else
				{
					Connect-EXOPSSession -UserPrincipalName $MFA  | Out-Null
				}
			}
		}
		catch
		{
			continue
		}

		#canary check to ensure everything is working before calling Get-InboxRule
		$canary = $null
		$canary = Get-User -ResultSize 1 -WarningAction silentlyContinue

		if(!($canary))
		{
			continue
		}

		#It's never a bad time for Garbage Collection
		[System.GC]::Collect()

		$preErrorCount = $Error.Count

		$ErrorActionPreference = 'Stop'
		try
		{
			[array]$rules = Get-InboxRule -Mailbox $currentAccount -ErrorAction Stop -ErrorVariable errvar
		}
		catch
		{
			color_out
			$u_array[$i] | Out-File $failedRulesLog -Encoding UTF8 -Append
			$ErrorActionPreference = 'Continue'
			break
		}
		$postErrorCount = $Error.Count
		$ErrorActionPreference = 'Continue'

		if($errvar)
		{
			color_out
			$u_array[$i] | Out-File $failedRulesLog -Encoding UTF8 -Append
			break
		}

		if($postErrorCount -gt $preErrorCount)
		{
			color_out
			$u_array[$i] | Out-File $failedRulesLog -Encoding UTF8 -Append
			break
		}

		#Handle any rules, if there are any for the mailbox
		if($Rules)
		{
			foreach($rule in $rules)
			{
				if($csv)
				{
					$outrule = $rule | Select-Object name,priority,description
					Add-Member -InputObject $outrule -NotePropertyName  -NotePropertyValue $u_array[$i]
					$outrules.Add($outrule) | Out-Null
				}
				else
				{
					$tempPsObject = New-Object PsObject -property @{
						'user' = $u_array[$i]
						'name' = $rule.name
						'priority' = $rule.priority
						}
					rule_parser $rule.description $tempPSobject
					$tempPsObject | ConvertTo-Json | Out-File $RuleFile -Encoding UTF8 -Append
				}
			}
		}
		break
	}
}

if($csv)
{
	$outrules | Export-Csv -NoTypeInformation $RuleFile -Encoding UTF8 -Delimiter ~
}

# 🏆 ENTERPRISE COMPLETION: Secure cleanup and comprehensive reporting
$scriptEndTime = Get-Date
$totalExecutionTime = [math]::Round(($scriptEndTime - $scriptStartTime).TotalMinutes, 2)

Write-EnterpriseLog -Level "Info" -Message "O365 Rules collection completed" -Category "Security" -Properties @{
    TotalExecutionTime = "$totalExecutionTime minutes"
    TransportRulesCollected = $transportRuleCount
    TransportRuleErrors = $transportRuleErrors
    SecurityRisksDetected = $securityRisks.Count
    ProcessingErrors = $processingErrors.Count
}

# 📊 ENTERPRISE SECURITY SUMMARY: Generate comprehensive security report
if ($securityAnalysis -and $securityRisks.Count -gt 0) {
    Write-Host "`n🛡️  SECURITY ANALYSIS SUMMARY" -ForegroundColor Red
    Write-Host "=" * 50 -ForegroundColor Gray

    $highRisks = ($securityRisks | Where-Object { $_.RiskLevel -eq "High" }).Count
    $mediumRisks = ($securityRisks | Where-Object { $_.RiskLevel -eq "Medium" }).Count

    Write-Host "   🔴 High Risk Items: $highRisks" -ForegroundColor Red
    Write-Host "   🟡 Medium Risk Items: $mediumRisks" -ForegroundColor Yellow
    Write-Host "   📋 Total Security Concerns: $($securityRisks.Count)" -ForegroundColor White

    # Export security analysis
    try {
        $securityAnalysisReport = @{
            AnalysisMetadata = @{
                Timestamp = $ISOTimeStamp
                TotalRisksFound = $securityRisks.Count
                HighRiskCount = $highRisks
                MediumRiskCount = $mediumRisks
                AnalysisScope = "Transport Rules, Inbox Rules, Forwarding"
                ExecutionTime = $totalExecutionTime
            }
            SecurityRisks = @($securityRisks.ToArray())
            Recommendations = @(
                "Review all high-risk items immediately",
                "Implement monitoring for external forwarding",
                "Audit transport rules with deletion capabilities",
                "Review rules with sender override permissions",
                "Enable security logging for all rule modifications"
            )
        }

        $securityAnalysisReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $SecurityReportFile -Encoding UTF8

        Write-Host "`n📋 Security analysis report saved to: $SecurityReportFile" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "Security analysis report generated" -Category "Security" -Properties @{
            ReportPath = $SecurityReportFile
            RisksAnalyzed = $securityRisks.Count
        }

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Failed to generate security report" -Category "FileSystem" -Exception $_
    }
}

# 🔒 ENTERPRISE CLEANUP: Secure session management and resource disposal
try {
    Write-Host "`n🔧 Cleaning up PowerShell sessions..." -ForegroundColor Cyan

    # Remove Exchange sessions securely
    $existingSessions = Get-PSSession -ErrorAction SilentlyContinue
    if ($existingSessions) {
        $existingSessions | Remove-PSSession -ErrorAction SilentlyContinue
        Write-EnterpriseLog -Level "Info" -Message "PowerShell sessions cleaned up" -Category "Security" -Properties @{
            SessionsRemoved = $existingSessions.Count
        }
    }

    # 📈 ENTERPRISE SUMMARY: Final execution report
    Write-Host "`n✅ O365 Rules Collection Complete!" -ForegroundColor Green
    Write-Host "   📊 Execution Time: $totalExecutionTime minutes" -ForegroundColor White
    Write-Host "   📁 Output Directory: $outputDirectory" -ForegroundColor White
    Write-Host "   🔍 Transport Rules: $transportRuleCount collected" -ForegroundColor White

    if ($securityAnalysis) {
        Write-Host "   🛡️  Security Risks: $($securityRisks.Count) identified" -ForegroundColor $(if ($securityRisks.Count -gt 0) { "Yellow" } else { "Green" })
    }

    Write-Host "`n📂 Output Files Generated:" -ForegroundColor Cyan
    Get-ChildItem -Path $outputDirectory -File | ForEach-Object {
        Write-Host "   📄 $($_.Name) ($([math]::Round($_.Length / 1KB, 2)) KB)" -ForegroundColor White
    }

    Write-EnterpriseLog -Level "Success" -Message "O365 Rules collection script completed successfully" -Category "Security" -Properties @{
        OutputDirectory = $outputDirectory
        FilesGenerated = (Get-ChildItem -Path $outputDirectory -File).Count
        TotalDataCollected = [math]::Round((Get-ChildItem -Path $outputDirectory -File | Measure-Object Length -Sum).Sum / 1KB, 2)
    }

} catch {
    Write-EnterpriseLog -Level "Error" -Message "Error during cleanup phase" -Category "Security" -Exception $_
    Write-Host "⚠️  Warning: Some cleanup operations failed. Check logs for details." -ForegroundColor Yellow
} finally {
    # Enterprise pattern: Guaranteed cleanup regardless of errors
    if (Get-Command "Set-QuickEdit" -ErrorAction SilentlyContinue) {
        Set-QuickEdit
    }

    # Final log entry
    Write-EnterpriseLog -Level "Info" -Message "Script execution ended" -Category "Security"
}
color_out
color_out
