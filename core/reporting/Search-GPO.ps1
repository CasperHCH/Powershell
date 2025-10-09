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
        [Parameter(Mandatory = $True, HelpMessage = "Specify the string to search for within the GPOs.")]
        [string]$String
    )

    Begin {
        # Set the domain to search for GPOs
        $DomainName = $env:USERDNSDOMAIN

        # Import the GroupPolicy module
        Try {
            Import-Module GroupPolicy -ErrorAction Stop
        } Catch {
            Write-Warning "Failed to import GroupPolicy module: $_"
            Break
        }

        # Initialize the matched GPO list
        [string[]]$MatchedGPOList = @()
    }

    Process {
        # Find all GPOs in the current domain
        Write-Host "Searching for GPOs in domain: $DomainName" -ForegroundColor Cyan
        $allGposInDomain = Get-GPO -All -Domain $DomainName

        # Look through each GPO's XML for the string
        foreach ($gpo in $allGposInDomain) {
            $report = Get-GPOReport -Guid $gpo.Id -ReportType Xml

            if ($report -match $String) {
                Write-Host "Match found in GPO: $($gpo.DisplayName)" -ForegroundColor Green
                $MatchedGPOList += $gpo.DisplayName
            }
        }

        # Output the matched GPOs
        if ($MatchedGPOList.Count -gt 0) {
            Write-Host "Matched GPOs:" -ForegroundColor Cyan
            $MatchedGPOList | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
        } else {
            Write-Host "No GPOs matched the search string." -ForegroundColor Red
        }
    }

    End {
        Write-Host "Search completed." -ForegroundColor Cyan
    }
}

# Example usage:
# Search-GPO -String "example"