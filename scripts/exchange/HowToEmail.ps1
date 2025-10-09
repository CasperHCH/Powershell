<#
.SYNOPSIS
    Send email using SMTP with secure credentials
.DESCRIPTION
    Example script showing how to send email using PowerShell with secure credential handling.
.NOTES
    Configure credentials securely before using this script.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$To,
    [Parameter(Mandatory=$true)]
    [string]$From,
    [string]$Subject = "Monthly Report",
    [string]$Body = "Good Morning",
    [string]$SmtpServer = "smtp.gmail.com",
    [int]$Port = 587
)

try {
    # Prompt for credentials securely
    $Credential = Get-Credential -Message "Enter email credentials"

    $msg = New-Object Net.Mail.MailMessage
    $smtp = New-Object Net.Mail.SmtpClient($SmtpServer, $Port)
    $smtp.EnableSsl = $True
    $smtp.Credentials = $Credential.GetNetworkCredential()

    $msg.From = $From
    $msg.To.Add($To)
    $msg.Subject = $Subject
    $msg.Body = $Body

    Write-Host "Sending email to $To..." -ForegroundColor Cyan
    $smtp.Send($msg)
    Write-Host "✅ Email sent successfully" -ForegroundColor Green

} catch {
    Write-Host "❌ Error sending email: $($_.Exception.Message)" -ForegroundColor Red
}

## Reference: https://support.google.com/accounts/answer/185833
## Use App Passwords for Gmail authenticationsmtp.gmail.com”
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
