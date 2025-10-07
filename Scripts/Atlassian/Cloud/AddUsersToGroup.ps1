    <#
    .SYNOPSIS
        Adds users to an Atlassian Cloud group by searching for their Account IDs using email addresses from a CSV file, then adding them to the specified group via the Atlassian Cloud API. Supports logging and a "WhatIf" mode for dry runs.

    .DESCRIPTION
        This script reads a list of user email addresses from a CSV file, searches for each user in Atlassian Cloud to retrieve their Account ID, and then adds each user to a specified Atlassian Cloud group using the REST API.
        All actions and results are logged to a file. The script supports a "WhatIf" switch to simulate the process without making any changes.

    .PARAMETER AccessToken
        The Atlassian Cloud API access token (Bearer token) used for authentication.

    .PARAMETER WhatIf
        If specified, the script will simulate adding users to the group without making any changes.

    .NOTES
        - Requires curl to be available in the system path.
        - The CSV file must contain a column named 'email'.
        - Ensure the AccessToken has the necessary permissions to search users and manage group memberships.

    .EXAMPLE
        .\AddUsersToGroup.ps1 -AccessToken "<your_token>" -WhatIf

    #>
param(
    [Parameter(Mandatory=$true)]
    [string]$CsvPath,
    [Parameter(Mandatory=$true)]
    [string]$GroupId,
    [Parameter(Mandatory=$true)]
    [string]$OrgId,
    [Parameter(Mandatory=$true)]
    [string]$Username,
    [Parameter(Mandatory=$true)]
    [string]$AccessToken,
	[Parameter(Mandatory=$true)]
	[String]$CustomerDomain,
    [switch]$WhatIf
)

$LogPath = "./AddUsersToGroups.log"
$UserSearchUrl = "https://$($CustomerDomain).atlassian.net/rest/api/3/user/search"
$GroupAddUrl = "https://$($CustomerDomain).atlassian.net/rest/api/3/group/user?groupId=$GroupId"

function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $Message" | Out-File -FilePath $LogPath -Append
}

# Read emails from CSV
$emails = Import-Csv -Path $CsvPath | ForEach-Object { $_.email }

foreach ($email in $emails) {
    Log "Searching for user with email: $email"
    $searchUrl = $UserSearchUrl +"?query=$email"
    $searchCmd = "curl -s -L -X GET `"$searchUrl`" --user '${Username}:${AccessToken}' -H `"Accept: application/json`""
    Log $searchCmd
    $json = Invoke-Expression $searchCmd
    Log "Response: $json"
    $searchResult = $json | ConvertFrom-Json

    if ($searchResult.Count -eq 0) {
        Log "User not found for email: $email"
        continue
    }

    $accountId = $searchResult[0].accountId
    Log "Found AccountId $accountId for $email"

    if ($WhatIf) {
        Log "WhatIf: Would add user $email (AccountId: $accountId) to group $GroupId"
        continue
    }

    $addBody = @{ accountId = $accountId } | ConvertTo-Json
    $addCmd = "curl -s -L -X POST `"$GroupAddUrl`" --user '${Username}:${AccessToken}' -H `"Content-Type: application/json`" -d '$addBody'"
    $addResult = Invoke-Expression $addCmd | ConvertFrom-Json

    if (!$addResult.errorMessages) {
        Log "Successfully added $email (AccountId: $accountId) to group $GroupId. Response: $($addResult | ConvertTo-Json -Compress)"
    } else {
        Log "Failed to add $email (AccountId: $accountId) to group $GroupId. Response: $($addResult | ConvertTo-Json -Compress)"
    }
}
