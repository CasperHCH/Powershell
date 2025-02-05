<#
.SYNOPSIS
	Sends an email message
.DESCRIPTION
	This PowerShell script sends an email message.
.PARAMETER From
	Specifies the sender email address
.PARAMETER To
	Specifies the recipient email address
.PARAMETER Subject
	Specifies the subject line
.PARAMETER Body
	Specifies the body message
.EXAMPLE
	PS> ./send-email
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$From = , [string]$To = , [string]$Subject = , [string]$Body = , [string]$SMTPServer = )

try {
	if ($From -eq ) {    $From = Read-Host  }
	if ($To -eq ) {      $To = Read-Host  }
	if ($Subject -eq ) { $Subject = Read-Host  }
	if ($Body -eq ) {    $Body = Read-Host  }
	if ($SMTPServer -eq ) { $SMTPServer = Read-Host  }

	$msg = New-Object Net.Mail.MailMessage
	$smtp = New-Object Net.Mail.SmtpClient($smtpServer)
	$msg.From = $From
	$msg.ReplyTo = $From
	$msg.To.Add($To)
	$msg.subject = $Subject
	$msg.body = $Body
	$smtp.Send($msg)
	
	exit 0 # success
} catch {
	
	exit 1
}
