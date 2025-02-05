$smtpserver = “smtp.gmail.com”
$msg = new-object Net.Mail.MailMessage
$smtp = new-object Net.Mail.SmtpClient($smtpServer, 587)
$smtp.EnableSsl = $True
$smtp.Credentials = New-Object System.Net.NetworkCredential(“chc@miracle.dk”, “Valmuevej4”); # Put username without the @GMAIL.com or – @gmail.com
$msg.From = “chc@miracle.dk”
$msg.To.Add()
$msg.Subject = 
$msg.Body = 
$smtp.Send($msg)



##https://support.google.com/accounts/answer/185833
#adgangskode til chjensen91  -  xrnmmwvyxdlxmcpd
