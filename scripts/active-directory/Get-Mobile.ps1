<#
.SYNOPSIS
Sends a mobile device statistics report for a mailbox user.

.DESCRIPTION
Queries Active Directory for requester and target user metadata, collects mobile device
statistics from Exchange, and sends the results as an HTML email.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Requester,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SmtpServer,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$MailFrom,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string[]]$MailTo,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string[]]$MailCc,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru
)

Import-Module ActiveDirectory -ErrorAction Stop

$requesterUser = Get-ADUser -Identity $Requester -Properties GivenName, Mail -ErrorAction Stop
$targetUser = Get-ADUser -Identity $UserId -Properties DisplayName, Mail -ErrorAction Stop

$deviceStats = @(Get-MobileDeviceStatistics -Mailbox $targetUser.Mail -ErrorAction Stop |
    Select-Object DeviceType, DeviceModel, DeviceFriendlyName, DeviceOS, DeviceUserAgent,
        LastSyncAttemptTime, LastSuccessSync, NumberOfFoldersSynced)

$style = @'
<style>
body { font-family: Segoe UI, Tahoma, sans-serif; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #d0d7de; padding: 6px 8px; text-align: left; }
th { background-color: #f3f6f9; }
</style>
'@

$preContent = "<h2>Mobile Device Report</h2><p>Requester: $($requesterUser.GivenName)</p><p>User: $($targetUser.DisplayName) ($($targetUser.Mail))</p><p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>"
$body = if ($deviceStats.Count -gt 0) {
    $deviceStats | ConvertTo-Html -Head $style -PreContent $preContent
}
else {
    "$style$preContent<p>No mobile device statistics were found for this mailbox.</p>"
}

$message = [System.Net.Mail.MailMessage]::new()
$message.From = $MailFrom
foreach ($address in $MailTo) {
    [void]$message.To.Add($address)
}
foreach ($address in $MailCc) {
    [void]$message.CC.Add($address)
}

$message.Subject = "Mobile device report for $($targetUser.DisplayName)"
$message.IsBodyHtml = $true
$message.Body = $body

$smtpClient = [System.Net.Mail.SmtpClient]::new($SmtpServer)
$smtpClient.Send($message)

if ($PassThru) {
    $deviceStats
}