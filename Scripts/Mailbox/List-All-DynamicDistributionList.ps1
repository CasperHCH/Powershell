$name = read-host 
$members = Get-DynamicDistributionGroup -Identity 
Get-Recipient -RecipientPreviewFilter $members.RecipientFilter | measure
