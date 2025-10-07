param(
    [Parameter(Mandatory=$true)]
    [string]$To,
    
    [Parameter(Mandatory=$true)]
    [string]$Subject,
    
    [Parameter(Mandatory=$true)]
    [string]$Body,
    
    [string]$From = "your-email@gmail.com",
    
    [Parameter(Mandatory=$true)]
    [System.Management.Automation.PSCredential]$Credential
)

function Send-GmailMessage {
    param(
        [string]$To,
        [string]$Subject,
        [string]$Body,
        [string]$From,
        [System.Management.Automation.PSCredential]$Credential
    )
    
    try {
        $smtpserver = "smtp.gmail.com"
        $msg = New-Object Net.Mail.MailMessage
        $smtp = New-Object Net.Mail.SmtpClient($smtpServer, 587)
        $smtp.EnableSsl = $True
        $smtp.Credentials = $Credential.GetNetworkCredential()
        
        $msg.From = $From
        $msg.To.Add($To)
        $msg.Subject = $Subject
        $msg.Body = $Body
        
        $smtp.Send($msg)
        Write-Host "Gmail message sent successfully to $To" -ForegroundColor Green
        
    } catch {
        Write-Error "Failed to send Gmail message: $($_.Exception.Message)"
    } finally {
        if ($msg) { $msg.Dispose() }
        if ($smtp) { $smtp.Dispose() }
    }
}

# If running as script (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    Send-GmailMessage -To $To -Subject $Subject -Body $Body -From $From -Credential $Credential
}

# Example usage:
# $cred = Get-Credential
# .\Send-GmailMessage.ps1 -To "recipient@domain.com" -Subject "Monthly Report" -Body "Good Morning" -From "your-email@gmail.com" -Credential $cred

##https://support.google.com/accounts/answer/185833
# Use App Passwords for Gmail authentication - never store passwords in scripts!