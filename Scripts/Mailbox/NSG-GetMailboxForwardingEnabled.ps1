$domains = Get-AcceptedDomain
$mailboxes = Get-Mailbox -ResultSize Unlimited
 
foreach ($mailbox in $mailboxes) {
 
    $forwardingRules = $null
#    Write-Host  -ForegroundColor Green
    $rules = Get-InboxRule -Mailbox $mailbox.PrimarySmtpAddress
     
    $forwardingRules = $rules | Where-Object {$_.ForwardTo -or $_.ForwardAsAttachmentTo}
 
    foreach ($rule in $forwardingRules) {
        $recipients = @()
        $recipients = $rule.ForwardTo | Where-Object {$_ -match }
        $recipients += $rule.ForwardAsAttachmentTo | Where-Object {$_ -match }
     
        $externalRecipients = @()
 
        foreach ($recipient in $recipients) {
            $email = ($recipient -split )[1].Trim()
            $domain = ($email -split )[1]
 
            if ($domains.DomainName -notcontains $domain) {
                $externalRecipients += $email
            }    
        }
 
        if ($externalRecipients) {
            $extRecString = $externalRecipients -join 
            Write-Host  -ForegroundColor Yellow
 
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
