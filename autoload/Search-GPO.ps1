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
    #$String = Read-Host -Prompt 

    # Set the domain to search for GPOs
    $DomainName = $env:USERDNSDOMAIN

    # Find all GPOs in the current domain
    write-host 
    Import-Module grouppolicy
    $allGposInDomain = Get-GPO -All -Domain $DomainName
    [string[]] $MatchedGPOList = @()

    # Look through each GPO's XML for the string
    Write-Host 
    
    foreach ($gpo in $allGposInDomain) {
        $report = Get-GPOReport -Guid $gpo.Id -ReportType Xml
    
        if ($report -match $String) {
            #write-host  -foregroundcolor 
            $MatchedGPOList += ;
        }

        else {
            #Write-Host 
        }
    }
    
    Write-Host  -foregroundcolor 
    
    foreach ($match in $MatchedGPOList) {
        write-host  -foregroundcolor 
    }
}
