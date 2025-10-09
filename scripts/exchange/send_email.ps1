param(
    [Parameter(Mandatory=$true)]
    [st$msg.From = "chc@miracle.dk"
$msg.To.Add("recipient@example.com")
$msg.Subject = "Default Subject"
$msg.Body = "Default message body"
$smtp.Send($msg)$To,

    [Parameter(Mandatory=$true)]
    [string]$Subject,

    [Parameter(Mandatory=$true)]
    [string]$Body,

    [string]$From = "your-email@domain.com",
    [string]$SmtpServer = "smtp.gmail.com",
    [int]$Port = 587,

    [Parameter(Mandatory=$true)]
    [System.Management.Automation.PSCredential]$Credential
)

try {
    $msg = New-Object Net.Mail.MailMessage
    $smtp = New-Object Net.Mail.SmtpClient($SmtpServer, $Port)
    $smtp.EnableSsl = $True
    $smtp.Credentials = $Credential.GetNetworkCredential()

    $msg.From = $From
    $msg.To.Add($To)
    $msg.Subject = $Subject
    $msg.Body = $Body

    $smtp.Send($msg)
    Write-Host "Email sent successfully to $To" -ForegroundColor Green

} catch {
    Write-Error "Failed to send email: $($_.Exception.Message)"
} finally {
    if ($msg) { $msg.Dispose() }
    if ($smtp) { $smtp.Dispose() }
}

# Example usage:
# $cred = Get-Credential
# .\send_email.ps1 -To "recipient@domain.com" -Subject "Test" -Body "Hello World" -Credential $cred

##https://support.google.com/accounts/answer/185833
# Use App Passwords for Gmail authenticationsmtp.gmail.com”
$msg = new-object Net.Mail.MailMessage
$smtp = new-object Net.Mail.SmtpClient($smtpServer, 587)
$smtp.EnableSsl = $True
$smtp.Credentials = New-Object System.Net.NetworkCredential(“chc@miracle.dk”, “Valmuevej4”); # Put username without the @GMAIL.com or – @gmail.com
$msg.From = “chc@miracle.dk”
$msg.To.Add("recipient@example.com")
$msg.Subject = "Test Subject"
$msg.Body = "Test Message Body"
$smtp.Send($msg)



##https://support.google.com/accounts/answer/185833
#adgangskode til chjensen91  -  xrnmmwvyxdlxmcpd
