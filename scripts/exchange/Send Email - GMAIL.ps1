<#
.SYNOPSIS
    Secure Gmail SMTP email sending

.DESCRIPTION
    Security-hardened Gmail email sending script with parameterized authentication.
    This script demonstrates proper credential management for Gmail SMTP.

.PARAMETER To
    Recipient email address

.PARAMETER From
    Sender Gmail address

.PARAMETER Subject
    Email subject line

.PARAMETER Body
    Email message body

.PARAMETER GmailAppPassword
    Gmail app password (secure string recommended)

.EXAMPLE
    .\Send-Email-GMAIL.ps1 -To "recipient@contoso.com" -From "sender@gmail.com" -Subject "Test" -Body "Hello"

.NOTES
    SECURITY CLASSIFICATION: CONFIDENTIAL
    REFERENCE: https://support.google.com/accounts/answer/185833
    REQUIRES: Gmail App Password (not regular password)
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Recipient email address")]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$To,

    [Parameter(Mandatory=$true, HelpMessage="Sender Gmail address")]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@gmail\.com$')]
    [string]$From,

    [Parameter(Mandatory=$true, HelpMessage="Email subject")]
    [ValidateNotNullOrEmpty()]
    [string]$Subject,

    [Parameter(Mandatory=$true, HelpMessage="Email body")]
    [ValidateNotNullOrEmpty()]
    [string]$Body,

    [Parameter(Mandatory=$false, HelpMessage="Gmail app password")]
    [string]$GmailAppPassword
)

# Secure credential prompt if not provided
if (-not $GmailAppPassword) {
    $securePassword = Read-Host "Enter Gmail App Password for $From" -AsSecureString
    $GmailAppPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
}

try {
    Write-Host "📧 Sending secure Gmail SMTP message" -ForegroundColor Cyan

    $smtpServer = "smtp.gmail.com"
    $msg = New-Object Net.Mail.MailMessage
    $smtp = New-Object Net.Mail.SmtpClient($smtpServer, 587)

    $smtp.EnableSsl = $true
    $smtp.Credentials = New-Object System.Net.NetworkCredential($From, $GmailAppPassword)

    $msg.From = $From
    $msg.To.Add($To)
    $msg.Subject = $Subject
    $msg.Body = $Body

    $smtp.Send($msg)
    Write-Host "✅ Email sent successfully to $To" -ForegroundColor Green

} catch {
    Write-Host "❌ Error sending email: $($_.Exception.Message)" -ForegroundColor Red
    throw
} finally {
    # Secure cleanup
    if ($msg) { $msg.Dispose() }
    if ($smtp) { $smtp.Dispose() }
    $GmailAppPassword = $null
}smtp.gmail.com”
$msg = new-object Net.Mail.MailMessage
$smtp = new-object Net.Mail.SmtpClient($smtpServer, 587)
$smtp.EnableSsl = $True
$smtp.Credentials = New-Object System.Net.NetworkCredential(“chc@miracle.dk”, “Valmuevej4”); # Put username without the @GMAIL.com or – @gmail.com
$msg.From = “chc@miracle.dk”
$msg.To.Add("chjensen91@gmail.com”)
$msg.Subject = “Monthly Report”
$msg.Body = “Good Morning”
$smtp.Send($msg)



##https://support.google.com/accounts/answer/185833
#adgangskode til chjensen91  -  xrnmmwvyxdlxmcpd
