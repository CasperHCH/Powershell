<#
.SYNOPSIS
    Enterprise-grade Exchange mailbox forwarding rule analysis and detection

.DESCRIPTION
    Detects and reports external email forwarding rules across all Exchange mailboxes
    with enterprise logging, performance optimization, and comprehensive error handling.

.PARAMETER OutputPath
    Path to export results (default: creates timestamped file)

.PARAMETER IncludeInternal
    Include internal forwarding rules in results

.PARAMETER MaxParallelJobs
    Maximum concurrent mailbox processing jobs (default: 10)

.EXAMPLE
    .\Get-MailboxForwardingEnabled.ps1 -OutputPath "C:\Reports\ForwardingRules.csv"

.NOTES
    Enterprise Pattern: Platinum Standard Exchange Management
    Security Level: Enterprise Grade
    Performance: Parallel processing with throttling
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\ExternalForwardingRules_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    [switch]$IncludeInternal,
    [int]$MaxParallelJobs = 10
)

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise logging framework
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

try {
    Write-EnterpriseLog -Level "Info" -Message "Starting Exchange mailbox forwarding analysis" -Category "Exchange" -Properties @{
        OutputPath = $OutputPath
        IncludeInternal = $IncludeInternal.IsPresent
        MaxParallelJobs = $MaxParallelJobs
    }

    # ⚡ ENTERPRISE PERFORMANCE: Measure operation performance
    $results = Measure-EnterpriseOperation -Name "ExchangeForwardingAnalysis" -ScriptBlock {

        # 🔒 ENTERPRISE SECURITY: Secure domain and mailbox collection
        Write-EnterpriseLog -Level "Info" -Message "Collecting Exchange domain information" -Category "Exchange"
        $domains = $null
        try {
            $domains = Get-AcceptedDomain -ErrorAction Stop
            Write-EnterpriseLog -Level "Info" -Message "Successfully retrieved accepted domains" -Category "Exchange" -Properties @{
                DomainCount = $domains.Count
            }
        } catch {
            Write-EnterpriseLog -Level "Error" -Message "Failed to retrieve accepted domains" -Category "Exchange" -Exception $_
            throw "Cannot proceed without domain information: $($_.Exception.Message)"
        }

        Write-EnterpriseLog -Level "Info" -Message "Collecting mailbox information" -Category "Exchange"
        $mailboxes = $null
        try {
            $mailboxes = Get-Mailbox -ResultSize Unlimited -ErrorAction Stop
            Write-EnterpriseLog -Level "Info" -Message "Successfully retrieved mailbox list" -Category "Exchange" -Properties @{
                MailboxCount = $mailboxes.Count
            }
        } catch {
            Write-EnterpriseLog -Level "Error" -Message "Failed to retrieve mailbox list" -Category "Exchange" -Exception $_
            throw "Cannot proceed without mailbox information: $($_.Exception.Message)"
        }

        # ⚡ ENTERPRISE PERFORMANCE: Parallel processing with intelligent throttling
        $forwardingResults = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        $processedCount = 0
        $errorCount = 0
        $jobs = @()

        Write-EnterpriseLog -Level "Info" -Message "Initiating parallel mailbox processing" -Category "Exchange" -Properties @{
            TotalMailboxes = $mailboxes.Count
            MaxParallelJobs = $MaxParallelJobs
        }

        foreach ($mailbox in $mailboxes) {
            # 🔧 RESOURCE MANAGEMENT: Throttle concurrent jobs
            while ((Get-Job -State Running).Count -ge $MaxParallelJobs) {
                Start-Sleep -Milliseconds 200
                # Clean up completed jobs to prevent memory buildup
                Get-Job -State Completed | Remove-Job -Force
            }

            # Start background job for each mailbox
            $job = Start-Job -ScriptBlock {
                param($MailboxAddress, $Domains, $IncludeInternal)

                $result = @{
                    Success = $false
                    Mailbox = $MailboxAddress
                    ForwardingRules = @()
                    ProcessingTime = 0
                    ErrorMessage = $null
                }

                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                try {
                    $rules = Get-InboxRule -Mailbox $MailboxAddress -ErrorAction Stop
                    $forwardingRules = $rules | Where-Object {$_.ForwardTo -or $_.ForwardAsAttachmentTo}

                    foreach ($rule in $forwardingRules) {
                        $recipients = @()
                        $recipients = $rule.ForwardTo | Where-Object {$_ -match "SMTP:"}
                        $recipients += $rule.ForwardAsAttachmentTo | Where-Object {$_ -match "SMTP:"}

                        $externalRecipients = @()
                        $internalRecipients = @()

                        foreach ($recipient in $recipients) {
                            $email = ($recipient -split ":")[1].Trim()
                            $domain = ($email -split "@")[1]

                            if ($Domains.DomainName -notcontains $domain) {
                                $externalRecipients += $email
                            } else {
                                $internalRecipients += $email
                            }
                        }

                        # Create rule object if external recipients found or include internal is requested
                        if ($externalRecipients -or ($IncludeInternal -and $internalRecipients)) {
                            $ruleInfo = [PSCustomObject]@{
                                PrimarySmtpAddress = $MailboxAddress
                                RuleId = $rule.Identity
                                RuleName = $rule.Name
                                RuleDescription = $rule.Description
                                ExternalRecipients = ($externalRecipients -join "; ")
                                InternalRecipients = ($internalRecipients -join "; ")
                                TotalRecipients = ($recipients.Count)
                                RuleEnabled = $rule.Enabled
                                CreatedDate = $rule.InError
                                ProcessedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                            }
                            $result.ForwardingRules += $ruleInfo
                        }
                    }

                    $result.Success = $true
                } catch {
                    $result.ErrorMessage = $_.Exception.Message
                } finally {
                    $stopwatch.Stop()
                    $result.ProcessingTime = $stopwatch.ElapsedMilliseconds
                }

                return $result
            } -ArgumentList $mailbox.PrimarySmtpAddress, $domains, $IncludeInternal.IsPresent

            $jobs += $job
        }

        # Wait for all jobs to complete and collect results
        Write-EnterpriseLog -Level "Info" -Message "Waiting for parallel mailbox processing to complete" -Category "Exchange"
        $jobs | Wait-Job | Out-Null

        foreach ($job in $jobs) {
            try {
                $result = Receive-Job -Job $job
                if ($result.Success) {
                    $processedCount++
                    foreach ($rule in $result.ForwardingRules) {
                        $forwardingResults.Add($rule)
                    }
                } else {
                    $errorCount++
                    Write-EnterpriseLog -Level "Warning" -Message "Failed to process mailbox" -Category "Exchange" -Properties @{
                        Mailbox = $result.Mailbox
                        Error = $result.ErrorMessage
                        ProcessingTime = $result.ProcessingTime
                    }
                }
            } catch {
                $errorCount++
                Write-EnterpriseLog -Level "Error" -Message "Error processing job result" -Category "Exchange" -Exception $_
            } finally {
                Remove-Job -Job $job -Force
            }
        }

        # Convert results to array
        $finalResults = @($forwardingResults.ToArray())

        Write-EnterpriseLog -Level "Info" -Message "Mailbox processing completed" -Category "Exchange" -Properties @{
            ProcessedCount = $processedCount
            ErrorCount = $errorCount
            ForwardingRulesFound = $finalResults.Count
            TotalMailboxes = $mailboxes.Count
        }

        return $finalResults
    }

    # 📊 ENTERPRISE REPORTING: Export results with comprehensive reporting
    if ($results -and $results.Count -gt 0) {
        try {
            $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            Write-EnterpriseLog -Level "Info" -Message "Results exported successfully" -Category "Exchange" -Properties @{
                OutputPath = $OutputPath
                RecordCount = $results.Count
                FileSize = (Get-Item $OutputPath).Length
            }

            # 🚨 ENTERPRISE ALERTING: Alert on external forwarding rules
            $externalRulesCount = ($results | Where-Object { $_.ExternalRecipients }).Count
            if ($externalRulesCount -gt 0) {
                Write-EnterpriseLog -Level "Warning" -Message "External forwarding rules detected" -Category "Security" -Properties @{
                    ExternalRulesCount = $externalRulesCount
                    TotalRules = $results.Count
                    AlertLevel = "HIGH"
                }
            }

            Write-Host "✅ Analysis completed successfully!" -ForegroundColor Green
            Write-Host "📊 Results: $($results.Count) forwarding rules found" -ForegroundColor Cyan
            Write-Host "📁 Exported to: $OutputPath" -ForegroundColor Cyan

            return $results
        } catch {
            Write-EnterpriseLog -Level "Error" -Message "Failed to export results" -Category "Exchange" -Exception $_
            throw
        }
    } else {
        Write-EnterpriseLog -Level "Info" -Message "No forwarding rules found" -Category "Exchange"
        Write-Host "✅ Analysis completed - No forwarding rules detected" -ForegroundColor Green
        return @()
    }

} catch {
    Write-EnterpriseLog -Level "Critical" -Message "Exchange forwarding analysis failed" -Category "Exchange" -Exception $_
    Write-Host "❌ Analysis failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
} finally {
    # 🔧 RESOURCE CLEANUP: Ensure proper cleanup
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
    Write-EnterpriseLog -Level "Info" -Message "Exchange forwarding analysis completed" -Category "Exchange"
}

    $forwardingRules = $rules | Where-Object {$_.ForwardTo -or $_.ForwardAsAttachmentTo}

    foreach ($rule in $forwardingRules) {
        $recipients = @()
        $recipients = $rule.ForwardTo | Where-Object {$_ -match "SMTP:"}
        $recipients += $rule.ForwardAsAttachmentTo | Where-Object {$_ -match "SMTP:"}

        $externalRecipients = @()

        foreach ($recipient in $recipients) {
            $email = ($recipient -split ":")[1].Trim()
            $domain = ($email -split "@")[1]

            if ($domains.DomainName -notcontains $domain) {
                $externalRecipients += $email
            }
        }

        if ($externalRecipients) {
            $extRecString = $externalRecipients -join ", "
            Write-Host "External forwarding found for: $($mailbox.PrimarySmtpAddress)" -ForegroundColor Yellow

            $ruleHash = $null
            $ruleHash = [ordered]@{
                PrimarySmtpAddress = $mailbox.PrimarySmtpAddress
                DisplayName        = $mailbox.DisplayName
                RuleId             = $rule.Identity
                RuleName           = $rule.Name
                RuleDescription    = $rule.Description
                ExternalRecipients = $extRecString
            }
            $ruleObject = New-Object PSObject -Property $ruleHash
            #$ruleObject | Export-Csv C:\temp\externalrules.csv -NoTypeInformation -Append
            $ruleObject
        }
    }
}
