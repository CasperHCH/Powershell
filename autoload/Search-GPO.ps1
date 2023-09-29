######################################################### 
# 
# Name: Search-GPOs.ps1 
# Author: Tony Murray 
# Version: 1.0 
# Date: 13/07/2016 
# Comment: Simple search for GPOs within a domain 
# that match a given string 
######################################################## 
 
Function Search-GPO {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$String
    )

    # Get the string we want to search for
    #$String = Read-Host -Prompt "What string do you want to search for?"

    # Set the domain to search for GPOs
    $DomainName = $env:USERDNSDOMAIN

    # Find all GPOs in the current domain
    write-host "Finding all the GPOs in $DomainName"
    Import-Module grouppolicy
    $allGposInDomain = Get-GPO -All -Domain $DomainName
    [string[]] $MatchedGPOList = @()

    # Look through each GPO's XML for the string
    Write-Host "Starting search...."
    
    foreach ($gpo in $allGposInDomain) {
        $report = Get-GPOReport -Guid $gpo.Id -ReportType Xml
    
        if ($report -match $String) {
            #write-host "********** Match found in: $($gpo.DisplayName) **********" -foregroundcolor "Green"
            $MatchedGPOList += "$($gpo.DisplayName)";
        }

        else {
            #Write-Host "No match in: $($gpo.DisplayName)"
        }
    }
    
    write-host "`r`n"
    write-host "Results: **************" -foregroundcolor "Yellow"
    
    foreach ($match in $MatchedGPOList) {
        write-host "Match found in: $($match)" -foregroundcolor "Green"
    }
}