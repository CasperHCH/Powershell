$name = read-host "Please provide the name of the Dynamic Distribution Group, you want to list"
$members = Get-DynamicDistributionGroup -Identity "$($name)"
Get-Recipient -RecipientPreviewFilter $members.RecipientFilter | measure