#requires -version 4
<#
.SYNOPSIS
	<Overview of script>
.DESCRIPTION
	<Brief description of script>
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
	<Inputs if any, otherwise state None>
.OUTPUTS
	<Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        unknown
  Author:         mira.ojamo@knowit.fi
  Creation Date:  unknown
  Purpose/Change: rename usernames within on-prem atlassian app, but match KnowIT UPN
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

[CmdletBinding(SupportsShouldProcess)]
param(
    [PSCredential]
    $knowit,
    [PSCredential]
    $globalad,
    [PSCredential]
    $adware,
    $jirapat,
    $confluencepat,
    $adwareGroupOU = "OU=LocalSamlGroups,OU=Groups,OU=General,OU=Farm,DC=ad,DC=ware,DC=fi",
    $knowitlocalPrefix = "secg-moc-atlassian-",
    [switch]
    $VeryVerbose,
    [switch]
    $UsersAndGroupsCache,
    [switch]
    $MappingCache,
    [switch]
    $createAdwareGroups,
    [switch]
    $populateKnowitGroups,
    [switch]
    $changeJiraUsernames,
    [switch]
    $onlyLocalPrep,
    [switch]
    $skipDataProcessing,
    [switch]
    $skipArchivalCheck,
    $PreviousData,
    $jirabaseurl = "jira-test.knowitops.com", 				#Jira URL
    $confluencebaseurl = "confluence-test.knowitops.com", 	#Confluence URL
    $knowitdc = @("10.170.0.101", "10.170.0.102"), 			#KnowIT Domain controllers
    $adwaredc = @("tmp-adware-dc1", "tmp-adware-dc2"), 		#Customer AD's
    $globaladdc = @("tmpdc1", "tmpdc2", "tmpdc3"), 			#Old-on-prem AD's
    $transcriptpath = "C:\temp\"
)
$Host.PrivateData.WarningForegroundColor = "Magenta"
# We want info outputs always as it won't get passed to return values
$InformationPreference = "Continue"
$VerbosePreference = "Continue"
if ($host.UI.RawUI.WindowSize.Width -lt 170) {
    Write-Information "NOTE: Window less than 170 characters wide - some output will get line-wrapped"
}
#region Lazy parameter validation
while ($null -eq $knowit) {
    $knowit = Get-Credential -Message "Please enter knowit.local credentials for AD queries"
}
while ($null -eq $globalad) {
    $globalad = Get-Credential -Message "Please enter global.ad credentials for AD queries"
}
while ($null -eq $adware) {
    $adware = Get-Credential -Message "Please enter ADWARE credentials for AD queries"
}
while ($null -eq $jirapat) {
    Write-Host "Please create Personal Access Token in https://$jirabaseurl/secure/ViewProfile.jspa?selectedTab=com.atlassian.pats.pats-plugin:jira-user-personal-access-tokens and paste it here"
    $jirapat = Read-Host "Jira access token"
}
while ($null -eq $confluencepat) {
    Write-Host "Please create Personal Access Token in https://$confluencebaseurl/secure/ViewProfile.jspa?selectedTab=com.atlassian.pats.pats-plugin:jira-user-personal-access-tokens and paste it here"
    $confluencepat = Read-Host "Confluence access token"
}
#endregion
Start-Transcript -Path "$transcriptpath\$($MyInvocation.MyCommand.Name)-$((Get-Date).ToString("yyyy-MM-dd_HH.mm.ss")).log" | out-null
$starttime = Get-Date
Write-Information "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Starting"


#If group naming is longer than 63 characters, they need to be added here;
$longGroupNameMap = @{
    "owner-secg-moc-atlassian-Confluence-FIADVISORY-Resurssointi-restrictions" = "owner-secg-moc-atlassian-Confluence-FIADVISORY-Resurs-restr"
    "owner-secg-moc-atlassian-Jira-Cybercom-ISIT-Service-desk-agents-external" = "owner-secg-moc-atlassian-Jira-Cybercom-ISIT-SD-agents-external"
    "owner-secg-moc-atlassian-Jira-Cybercom-MOC-PL-Service-desk-agents"        = "owner-secg-moc-atlassian-Jira-Cybercom-MOC-PL-SD-agents"
    "owner-secg-moc-atlassian-Jira-Cybercom-OPSSOK-Service-desk-agents"        = "owner-secg-moc-atlassian-Jira-Cybercom-OPSSOK-SD-agents"
    "owner-secg-moc-atlassian-JiraConflu-MTV-General-Aineistosiirtopalvelu"    = "owner-secg-moc-atlassian-JiraConflu-MTV-General-Aspera"
    "secg-moc-atlassian-Confluence-FIADVISORY-Resurssointi-restrictions"       = "secg-moc-atlassian-Confluence-FIADVISORY-Resurs-restr"
    "secg-moc-atlassian-Jira-Cybercom-ISIT-Service-desk-agents-external"       = "secg-moc-atlassian-Jira-Cybercom-ISIT-SD-agents-external"
    "secg-moc-atlassian-Jira-Cybercom-MOC-PL-Service-desk-agents"              = "secg-moc-atlassian-Jira-Cybercom-MOC-PL-SD-agents"
    "secg-moc-atlassian-Jira-Cybercom-OPSSOK-Service-desk-agents"              = "secg-moc-atlassian-Jira-Cybercom-OPSSOK-SD-agents"
    "secg-moc-atlassian-JiraConflu-MTV-General-Aineistosiirtopalvelu"          = "secg-moc-atlassian-JiraConflu-MTV-General-Aspera"
}

#needs clarification
$specialgroups = @("667_users", "App_Jira_REXELSHOP", "App_SCD_Admin", "App_SCD_Dev", "App_SCD_User", "Confluence Finland All", "Confluence Finland Dace-external read-only", "confluence-administrators", "confluence-service-accounts-adware", "confluence-users-adware", "Cybercom (Worldwide)", "Cybercom Finland Jira users", "dace-admin-confluence", "dace-jyra", "dace-ohry", "DACE-pseudotunnukset", "DACE-pseudotunnukset-Insight-RO", "DACE-pseudotunnukset-Insight-RW", "DACE-pseudotunnukset-ServiceDeskTeam", "dace-sd", "dace-sec-dace", "DACEVainLukuPseudotunnukset", "FI BA Admin and General", "FI BA Connected Devices", "FI BA Data Center", "FI BA Digital Services", "FI BU Data Center", "FI BU Directors", "FI BU Finance", "FI BU HR", "FI BU ISIT", "FI BU Managed Cloud Services", "guru", "HR-Finland", "IS_IT.Finland", "IS_IT.Poland", "IS_IT.Sweden", "IS/IT", "Itella ALLSP", "jira-administrators", "jira-users", "jira-users-adware", "Jokakoti", "JokakotiConfluence", "Jyrä", "Kataloggruppen", "Linköping Innovation Zone", "luukku-admin", "luukku.tk", "Metso Bruno (projektiryhmä)", "MOC", "MOC-FI", "MTV-team-all", "mtv3-katsomotiimi", "mtvkatsomo", "MTVUsers", "Palvelut - Projektipaallikot", "palvelut-palveluvastaavat", "Palveluvastaavat", "SE Göteborg", "SE Oresund Karlskrona", "SE Site Karlskrona", "SP FI BA Data Center", "SP FI DC BU Data Center", "TeollisuusPP")

#Removal of nested groups / Flatening the group tree
Function Get-ADUserNestedGroups {
    [CmdletBinding()]
    Param
    (
        $group,
        [System.Collections.ArrayList]$Groups,
        $filter,
        $session,
        $intent = "",
        [switch]$dnonly,
        [switch]$VeryVerbose
    )
    if ($group.GetType().Name -eq "String") {
        if ($group -match "OU=") {
            if ($VeryVerbose.IsPresent) {
                Write-Verbose "$intent+ VeryVerbose: Group attribute string which matched  OU= - querying AD without -identity"
            }
            $group = invoke-command -session $session -ScriptBlock { Get-ADgroup ($Using:group) -Properties memberOf, DistinguishedName }
        }
        else {
            if ($VeryVerbose.IsPresent) {
                Write-Verbose "$intent+ VeryVerbose: Group attribute string - querying AD"
            }
            $group = invoke-command -session $session -ScriptBlock { Get-ADgroup -identity ($Using:group) -Properties memberOf, DistinguishedName }
        }
    }
    Write-Verbose "$intent Current: $((($group.DistinguishedName).substring(3) -split ",")[0])$(if($null -ne $filter){" - filter $filter, match $("{0,-5}" -f ($group.DistinguishedName -match $filter))"})"
    if ($null -ne $filter) {
        if ($group.DistinguishedName -match $filter) {
            if ($Group.DistinguishedName -notin $(if ($dnonly.IsPresent) { $Groups }else { $Groups.DistinguishedName })) {
                $Groups.Add($group) | Out-Null
            }
        }
    }
    else {
        if ($Group.DistinguishedName -notin $(if ($dnonly.IsPresent) { $Groups }else { $Groups.DistinguishedName })) {
            $Groups.Add($group) | Out-Null
        }
    }

    if ($null -ne $group.memberOf -or $group.memberOf.count -gt 0) {
        #Enummurate through each of the groups.
        Foreach ($GroupDistinguishedName in $group.memberOf) {
            if ($VeryVerbose.IsPresent) {
                Write-Verbose "$intent-- VeryVerbose: Checking groups $($group.name) is member of, current group $(($GroupDistinguishedName.substring(3) -split ",")[0])"
            }
            if ($GroupDistinguishedName -notin $(if ($dnonly.IsPresent) { $Groups }else { $Groups.DistinguishedName })) {
                #Get member of groups from the enummerated group.
                $ThisGroup = invoke-command -session $session -ScriptBlock { Get-ADgroup $Using:GroupDistinguishedName -Properties memberOf, DistinguishedName }
                if ($VeryVerbose.IsPresent) {
                    Write-Verbose "$intent-- VeryVerbose: Wasn't already in the group array, checking $($ThisGroup.MemberOf.count) nested groups"
                }
                #Get recursive groups.
                $ThisGroup.memberOf | foreach-object {
                    if ($VeryVerbose.IsPresent) {
                        Write-Verbose "$intent--- VeryVerbose: Nested-checking groups $($ThisGroup.name) is member of, current group $($ThisGroup.MemberOf.IndexOf($_) + 1)/$($ThisGroup.MemberOf.count) - $(($_.substring(3) -split ",")[0])"
                    }
                    Get-ADUserNestedGroups -group $_ -Groups $Groups -session $session -filter $filter -intent "$intent---" -VeryVerbose:$($VeryVerbose.IsPresent) -Verbose:$($VerbosePreference -eq "Continue") -dnonly:$dnonly.IsPresent | ForEach-Object -Process { if (-not $Groups.Contains($_)) { $Groups.Add($_) } } | Out-Null
                    if ($VeryVerbose.IsPresent) {
                        Write-Verbose "$intent--- VeryVerbose: Done checking group $(($_.substring(3) -split ",")[0]), continuing with next group"
                    }
                }
            }
            else {
                if ($VeryVerbose.IsPresent) {
                    Write-Verbose "$intent-- VeryVerbose: Was already in the group array"
                }
            }
            if ($VeryVerbose.IsPresent) {
                Write-Verbose "$intent- VeryVerbose: Done checking group $($CurrentGroup.MemberOf.IndexOf($GroupDistinguishedName) + 1)/$($CurrentGroup.MemberOf.count) ($(($GroupDistinguishedName.substring(3) -split ",")[0])), continuing to next one."
            }
        }
    }

    if ($dnonly.IsPresent) {
        $ret = $Groups.DistinguishedName
    }
    else {
        $ret = $Groups
    }
    Return $ret
}

Function FilterUPN {
    [CmdLetBinding()]
    param(
        [parameter(ValueFromPipeline, Mandatory = $true, ParameterSetName = "array")]
        [parameter(ValueFromPipeline, Mandatory = $true, ParameterSetName = "multidimensionalarray")]
        [parameter(ValueFromPipeline, Mandatory = $true, ParameterSetName = "string")]
        $pipe,
        [parameter(Mandatory = $true, ParameterSetName = "multidimensionalarray")]
        [parameter(Mandatory = $true, ParameterSetName = "array")]
        [parameter(Mandatory = $true, ParameterSetName = "string")]
        [string]
        $field,
        [parameter(Mandatory = $true, ParameterSetName = "multidimensionalarray")]
        [parameter(Mandatory = $true, ParameterSetName = "array")]
        $array,
        [parameter(Mandatory = $true, ParameterSetName = "multidimensionalarray")]
        [parameter(Mandatory = $true, ParameterSetName = "string")]
        [string]
        $string,
        [parameter(Mandatory = $true, ParameterSetName = "multidimensionalarray")]
        [switch]
        $multidimensional,
        [parameter(Mandatory = $false, ParameterSetName = "array")]
        [switch]
        $reverse
    )
    Process {
        if ($PSCmdlet.ParameterSetName -eq "array") {
            if ($reverse.IsPresent -and $pipe.$field -contains $array) {
                $pipe
            }
            elseif ($pipe.$field -in $array) {
                $pipe
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "string" -and $pipe.$field -eq $string) {
            $pipe
        }
        elseif ($multidimensional.IsPresent -and $pipe.$array.$field -eq $string) {
            $pipe
        }
    }
}

#region Preparation & Connectivity tests
$pssessionoptions = new-pssessionoption -OpenTimeout 10000 -CancelTimeout 10000 -OperationTimeout 10000 -MaxConnectionRetryCount 3 -NoCompression -NoMachineProfile


$dcsok = @{
    knowit   = [system.Collections.ArrayList]@()
    globalad = [system.collections.ArrayList]@()
    adware   = [system.collections.ArrayList]@()
}
$connectivityerrors = [System.Collections.ArrayList]@()

Write-Information "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Testing connectivities"
foreach ($dc in $knowitdc) {
    try {
        $dcip = [array][System.Net.Dns]::GetHostEntry($dc).addresslist.ipaddresstostring
    }
    catch {
        $dcip = @($dc)
    }
    foreach ($ip in $dcip) {
        try {
            $test = Get-ADUser -Filter "UserPrincipalName -eq '$($knowit.UserName)'" -Server $ip -Credential $knowit
        }
        catch {
            $connectivityerrors.Add("$dc/${ip}: $_") | Out-Null
        }
        if ($null -ne $test) {
            Write-Information "- Connectivity to knowit.local dc $dc/$ip - OK"
            $dcsok.knowit.Add($ip) | Out-Null
        }
        else {
            Write-Warning "- Connectivity to knowit.local dc $dc/$ip - FAILED"
        }
        $test = $null
    }
}
foreach ($dc in $globaladdc) {
    try {
        $dcip = [array][System.Net.Dns]::GetHostEntry($dc).addresslist.ipaddresstostring
    }
    catch {
        $dcip = @($dc)
    }
    foreach ($ip in $dcip) {
        try {
            $test = Get-ADUser ($globalad.UserName -split "\\")[1] -Server $ip -Credential $globalad
        }
        catch {
            $connectivityerrors.Add("$dc/${ip}: $_") | Out-Null
        }
        if ($null -ne $test) {
            Write-Information "- Connectivity to global.ad dc $dc/$ip - OK"
            $dcsok.globalad.Add($ip) | Out-Null
        }
        else {
            Write-Warning "- Connectivity to global.ad dc $dc/$ip - FAILED"
        }
        $test = $null
    }
}
foreach ($dc in $adwaredc) {
    try {
        $dcip = [array][System.Net.Dns]::GetHostEntry($dc).addresslist.ipaddresstostring
    }
    catch {
        $dcip = @($dc)
    }
    foreach ($ip in $dcip) {
        try {
            $test = Get-ADUser ($adware.UserName -split "\\")[1] -Server $ip -Credential $adware
        }
        catch {
            $connectivityerrors.Add("$dc/${ip}: $_") | Out-Null
        }
        if ($null -ne $test) {
            Write-Information "- Connectivity to adware dc $dc/$ip - OK"
            $dcsok.adware.Add($ip) | Out-Null
        }
        else {
            Write-Warning "- Connectivity to adware dc $dc/$ip - FAILED"
        }
        $test = $null
    }
}
try {
    $jiratokentest = Invoke-RestMethod -Uri "https://$jirabaseurl/rest/api/2/upgrade" -Headers @{Authorization = "Bearer $jirapat" } -Method Get -ErrorAction Stop -verbose:$false
}
catch {
    $connectivityerrors.Add("Jira: $_") | Out-Null
}

if ($dcsok.knowit.count -gt 0 -and $dcsok.globalad.count -gt 0 -and $dcsok.adware.count -gt 0 -and $null -ne $jiratokentest) {
    Write-Information "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Connectivity info:`n- Knowit.local DCs reached: $($dcsok.knowit.count)`n- Global.ad DCs reached: $($dcsok.globalad.count)`n- Adware DCs reached: $($dcsok.adware.count)$(if($connectivityerrors.count -ne 0){"`nCatched connectivity issues:`n- $($connectivityerrors -join "`n- ")`n`n"})"
    Write-Information "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] At least one DC reached for each domain, Jira reached - continuing"
}
else {
    Write-Error "Couldn't connect at least one DC in each domain. Please check errors below!"
    Write-Information "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Connectivity info:`n- Knowit.local DCs reached: $($dcsok.knowit.count)`n- Global.ad DCs reached: $($dcsok.globalad.count)`n- Adware DCs reached: $($dcsok.adware.count)$(if($connectivityerrors.count -ne 0){"`nCatched connectivity issues:`n- $($connectivityerrors -join "`n- ")`n`n"})"
    exit
}
#endregion

$gaserver = $dcsok.globalad[0]
$knowitserver = $dcsok.knowit[0]
Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Opening PSSession to $gaserver and $knowitserver"
$gadsession = new-pssession -ComputerName $gaserver -Credential $globalad -EnableNetworkAccess -SessionOption $pssessionoptions
$knowitsession = new-pssession -ComputerName $knowitserver -Credential $knowit -EnableNetworkAccess -SessionOption $pssessionoptions

$perfmetrics = @{
    GroupDiscovery     = $null
    MemberDiscovery    = $null
    UPNDiscovery       = $null
    GroupMapping       = $null
    DataCombine        = $null
    JiraUsernameChange = $null
    DataCoherencyCheck = $null
    PopulateGroups     = $null
}

#region Query group and user data separately
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
if (-not $UsersAndGroupsCache.IsPresent) {
    $g = [System.Collections.ArrayList]@()
    #region Discover global.ad groups and recursive memberships
    Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Querying Atlassian groups"
    $stopwatch.Restart()
    $gad = [System.Collections.ArrayList]@()
    invoke-command -session $gadsession -ScriptBlock { Get-ADGroup -SearchBase "OU=Dace,OU=Groups,OU=675,OU=Companies,DC=global,DC=ad" -filter "Name -like 'App_*'" } | Where-Object { $_.DistinguishedName -match "jira|conflu|insight|bitbucket|wiki" } | ForEach-Object -process { Get-ADUserNestedGroups -group $_ -session $gadsession -intent "-" -Groups $gad -dnonly -Verbose:$($VerbosePreference -eq "Continue") -VeryVerbose:$($VeryVerbose.IsPresent) | ForEach-Object -Process { if (-not $gad.Contains($_)) { $gad.Add($_) } } } | Out-Null
    # Handling oddities by hand - These groups are used in various places
    invoke-command -session $gadsession -ScriptBlock { $Using:specialgroups | Foreach-Object -Process { Get-ADGroup $_ } } | ForEach-Object -process { Get-ADUserNestedGroups -group $_ -session $gadsession -intent "-" -Groups $gad -dnonly -Verbose:$($VerbosePreference -eq "Continue") -VeryVerbose:$($VeryVerbose.IsPresent) | ForEach-Object -Process { if (-not $gad.Contains($_)) { $gad.Add($_) } } } | Out-Null
    $gad = $gad | Where-Object { $_ -notmatch "App_JiraConflu" } | Sort-Object -Unique
    $perfmetrics.GroupDiscovery = $stopwatch.Elapsed
    Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Found $($gad.count) groups, iterating (query took $([Math]::Round(($stopwatch.ElapsedMilliseconds / 60000),0)) min $([Math]::Round(($stopwatch.ElapsedMilliseconds / 1000),2))s)"
    $stopwatch.Restart()
    $groupcount = $gad.Count
    $groupmembermap = @{}
    $groupmemberships = $gad | Foreach-Object {
        $g.Add([PSCustomObject]@{
                Name        = ((([string]$_).substring(3) -split ",")[0])
                Description = (invoke-command -session $gadsession -ScriptBlock { Get-ADGroup ([string]$Using:_) -Properties Description }).Description
            }) | Out-Null
        $groupquerystart = $stopwatch.ElapsedMilliseconds
        $groupdata = invoke-command -session $gadsession -ScriptBlock { Get-ADGroupMember -identity ([string]$Using:_) -Recursive }
        $groupquery = $stopwatch.ElapsedMilliseconds - $groupquerystart
        Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - Group: {0,-55} - {1,4} members ({2,4} / {3,4} - data null? {4,5} - queried in {5,4}ms)" -f (([string]$_).substring(3) -split ",")[0], @($groupdata).count, $gad.IndexOf($_), $groupcount, ($null -eq $groupdata), $groupquery)
        [PSCustomObject]@{
            Group   = $((([string]$_).substring(3) -split ",")[0])
            members = $groupdata
        }
        if ($null -eq $groupmembermap.((([string]$_).substring(3) -split ",")[0])) {
            $groupmembermap += @{((([string]$_).substring(3) -split ",")[0]) = $groupdata }
        }
    }
    $stopwatch.Stop()
    $perfmetrics.MemberDiscovery = $stopwatch.Elapsed
    $stopwatch.Restart(); $stopwatch.Stop()
    #endregion
    $allusers = $groupmemberships.members | Sort-Object SAMAccountName -Unique
    $membercount = $allusers.count
    $usermap = @{}
    $i = 0
    $stopwatch.Restart()
    $users = $allusers | `
        Foreach-Object -process {
        $i++
        $userquerystart = $stopwatch.ElapsedMilliseconds
        $user = invoke-command -session $gadsession -ScriptBlock { get-aduser ($Using:_).DistinguishedName -Properties proxyaddresses, memberOf, mail }
        $userquery = $stopwatch.ElapsedMilliseconds - $userquerystart
        if ($user.enabled -eq $false) {
            Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] User: {0,-20} - disabled, skip {1,77} ({2,11} / {3,-12} - queried in {4,3}ms)" -f $_.samaccountname, "", $i, $membercount, $userquery)
        }
        elseif ($user.Name -match "\(Admin\)") {
            Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] User: {0,-20} - Admin-account, skip ({1,-58}) {2,11} ({3,11} / {4,-12} - queried in {5,3}ms)" -f $_.samaccountname, $user.Name, "", $i, $membercount, $userquery)
        }
        else {
            Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] User: {0,-20} - {1,-80} {2,11} ({3,11} / {4,-12} - queried in {5,3}ms)" -f $_.samaccountname, $user.Name, "", $i, $membercount, $userquery)
            [PSCustomObject]@{
                User = $user
                smtp = "smtp:$($user.UserPrincipalName)"
            }
        }
    } | ForEach-Object -process {
        #region Try to query and match global.ad user to knowit.local user using various methods
        $userdiscoverystart = $stopwatch.ElapsedMilliseconds
        if (-not $onlyLocalPrep.IsPresent) {
            $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter "proxyaddresses -like '$(($using:_).smtp)'" -Properties mail, manager }
            $foundwith = "-"
            if ($null -ne $knowituser) {
                # ~80% can be found with proxy. But not all.
                $foundwith = "Proxy"
            }
            # It was part of the ~20%? Alright, time for freaking brute forcing >_<
            if ($null -eq $knowituser -and $null -ne $_.user.mail -and $_.user.mail -match "knowit") {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter "userprincipalname -like '$(($using:_).user.mail)'" -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = "UPN"
                }
            }
            if ($null -eq $knowituser -and $null -ne $_.user.samaccountname) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter "samaccountname -like '$(($using:_).user.samaccountname)'" -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = "sAM"
                }
            }
            if ($null -eq $knowituser -and $null -ne $_.user.mail) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter "mail -like '$(($using:_).user.mail)'" -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = "Mail"
                }
            }
            if ($null -eq $knowituser -and $null -ne $_.user.mail) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter "proxyaddresses -like 'smtp:$(($using:_).user.mail)'" -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = "PMail"
                }
            }
            # Apparently the old email gets stored into this attribute in some instances
            if ($null -eq $knowituser -and $null -ne $_.user.mail) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter "extensionAttribute12 -like '$(($using:_).user.mail)'" -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = "Ext12"
                }
            }
            # As a last resort, try with name. There isn't that many people with same name in the size of our group, right? Right?!
            if ($null -eq $knowituser) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter "name -like '$(($using:_).user.name)'" -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = "Name"
                }
            }
            if ($knowituser.count -gt 1) {
                # This might do incorrect mappings but duplicates doesn't map anything
                $knowituser = $knowituser[0]
            }
        }
        else {
            Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Local prep, skipped knowit.local UPN discovery")
            $knowituser = $null
        }
        $userdiscovery = $stopwatch.ElapsedMilliseconds - $userdiscoverystart
        #endregion
        Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,10} Mapped: {1,45} -> {2,-40} / {3,-10} (success? {4,5}, with {5,5} - queried in {6,3}ms)" -f " ", $_.User.UserPrincipalName, $knowituser.UserPrincipalName, $knowituser.samaccountname, $($null -ne $knowituser), $foundwith, $userdiscovery)
        [PSCustomObject]@{
            GAUser     = $_.User
            GAsmtp     = $_.smtp
            KnowitUser = $knowituser
            KnowitSam  = $knowituser.samaccountname
            KnowitUPN  = $knowituser.UserPrincipalName
            Foundwith  = $foundwith
        }
        if ($null -ne $knowituser) {
            $usermap.($_.User.DistinguishedName) = $knowituser.UserPrincipalName
        }

    }
    $stopwatch.Stop()
    $perfmetrics.UPNDiscovery = $stopwatch.Elapsed
    $stopwatch.Restart(); $stopwatch.Stop()
}
else {
    Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Loading user and group data from provided cache"
    $users = $PreviousData.UserData
    $groupmemberships = $PreviousData.GroupData
    $g = $PreviousData.G
    $groupmembermap = $PreviousData.GroupMemberMap
    $usermap = $PreviousData.UserMap
}
#endregion
#region Map the group and user data together
if (-not $MappingCache.IsPresent) {
    Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Mapping group memberships"
    $stopwatch.Restart()
    try {
        $userswithgroups = foreach ($user in $users) {
            #$groups = $($_.GAUser.memberof | foreach-object { Get-ADUserNestedGroups -group $_ -filter "ou=jira|ou=confluence" -session $gadsession -intent ("  {0,-9} " -f $_.gauser.samaccountname) -Verbose:$VerboseGroupSearch.IsPresent }).Name
            $start = $stopwatch.ElapsedMilliseconds
            $groups = ($groupmemberships | FilterUPN -string $user.gauser.DistinguishedName -field distinguishedname -array members -multidimensional).group # Where-Object { $_.members.Distinguishedname -contains $user.gauser.DistinguishedName }).group
            $filterperf = $stopwatch.ElapsedMilliseconds - $start
            Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - User: {0,-50} {1,3} Atlassian groups - mapping (took {2,5} ms)" -f $user.GAUser.Name, $groups.count, $filterperf)
            [PSCustomObject]@{
                GAUser     = $user.GAUser
                GAGroups   = $groups
                GAsmtp     = $user.GAsmtp
                KnowitUser = $user.KnowitUser
                KnowitSam  = $user.KnowitSam
                KnowitUPN  = $user.KnowitUPN
                Foundwith  = $user.Foundwith
            }
        }
    }
    catch {
        Write-error -ErrorAction continue -Message "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Failed to map all group memberships! Continuing and returning rest of the data."
    }
    $stopwatch.Stop()
    $perfmetrics.GroupMapping = $stopwatch.Elapsed
    $stopwatch.Restart(); $stopwatch.Stop()
}
else {
    Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Loading mapping data of users and groups from provided cache"
    $userswithgroups = $PreviousData.UserDataWithGroups
}
#endregion

#region Main data parsing
$noKnowit = $users | Where-Object { $_.KnowitUser -eq $null }
$newemployees = $users | Where-Object { $_.GAUser.proxyaddresses -eq $null }

$createdAdwaregroups = [System.Collections.ArrayList]@()
$groupnamemax = ($g.name | Measure-Object -Maximum -Property Length).Maximum
$adwserver = ($dcsok.adware[0])
Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Opening PSSession to $adwserver"
$adwaresession = new-pssession -ComputerName $adwserver -Credential $adware -EnableNetworkAccess -SessionOption $pssessionoptions
$CSVs = [System.Collections.ArrayList]@()
Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Generating CSV data"
$lookup = @{}
$cache = @{
    Jira       = @{}
    Confluence = @{}
    Bitbucket  = @{}
    Insight    = @{}
}
$stopwatch.Restart()
if (-not $skipDataProcessing.IsPresent) {
    foreach ($gagroup in $g) {
        $usedDefaultOwners = $false
        $isOwnerGroup = $false
        if ($gagroup.name -match "(?<group>.*)(?<admin>_admin.*)") {
            $newname = ($matches["group"] -replace "App_", "owner-$knowitlocalPrefix") -replace "_", "-"
            $isOwnerGroup = $true
        }
        else {
            $newname = ($gagroup.name -replace "App_", $knowitlocalPrefix) -replace "_", "-"
        }
        if ($newname -notmatch "^((owner-)?$knowitlocalPrefix)") {
            # Special group, handling now
            $charreplace = $gagroup.name -replace '[ /_]', '-' -replace "ä", "a" -replace "ö", "o" -replace '[()]', '' -replace "---","-"
            $newname = "$knowitlocalPrefix$charreplace"
        }
        if ($newname -match "${knowitlocalPrefix}Wiki-") {
            $newname = $newname -replace "-Wiki-", "-Confluence-"
        }
        Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Current group: {0,-50} / {1,-50}" -f $gagroup.Name, $newname)
        #region Check archival status from relevant system
        $archivalstart = $stopwatch.ElapsedMilliseconds
        if (-not $skipArchivalCheck.IsPresent -and $gagroup.name -match "^App_") {
            if ($gagroup.name -match "Jira") {
                Write-verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Checking archival status of the Jira project" -f "")
                $projectinfo = $null
                $roledata = $null
                $project = ($gagroup.name -split "_")[2]
                if ($null -eq $cache.Jira.$project) {
                    Write-verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} -- Cache miss. Calling https://$jirabaseurl/rest/api/2/project/$project" -f "")
                    $success = $true
                    try {
                        $projectinfo = Invoke-RestMethod -Uri "https://$jirabaseurl/rest/api/2/project/$project" -Headers @{Authorization = "Bearer $jirapat" } -Method Get -verbose:$false
                    }
                    catch {
                        $success = $false
                    }
                    if ($success) {
                        $roledata = $projectinfo.roles."Project admin" | ForEach-Object {
                            Write-verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} -- Calling $_" -f "")
                            try {
                                Invoke-RestMethod -Uri "$_" -Headers @{Authorization = "Bearer $jirapat" } -Method Get -verbose:$false
                            }
                            catch {}
                        }
                    }
                    $cache.Jira += @{
                        $project = @{
                            archived    = (-not $success)
                            projectinfo = $projectinfo
                            roleinfo    = $roledata
                        }
                    }
                }
                if ($cache.Jira.$project.archived) {
                    Write-verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} -- Project looks like it's archived - processing anyway" -f "")
                }
                if ($null -ne $cache.Jira.$project.roleinfo.actors -and $gagroup.name -notin $cache.Jira.$project.roleinfo.actors.displayname) {
                    Write-Warning ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Group '{1}' not found from project '$project' role mappings" -f "", $gagroup.name)
                }
            }
            elseif ($gagroup.name -match "Confluence") {
                Write-verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Checking archival status Confluence space" -f "")
                $spaceinfo = $null
                #$roledata = $null
                $space = ($gagroup.name -split "_")[2]
                if ($null -eq $cache.Confluence.$space) {
                    Write-verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} -- Cache miss. Calling https://$confluencebaseurl/rest/api/space/$space" -f "")
                    $success = $true
                    try {
                        $spaceinfo = Invoke-RestMethod -Uri "https://$confluencebaseurl/rest/api/space/$space" -Headers @{Authorization = "Bearer $confluencepat" } -Method Get -verbose:$false
                    }
                    catch {
                        $success = $false
                    }
                    $cache.Confluence.$space += @{
                        $space = @{
                            archived  = (-not $success)
                            spaceinfo = $spaceinfo
                        }
                    }
                }
                if ($cache.Confluence.$space.archived) {
                    Write-verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} -- Space looks like it's archived - processing anyway" -f "")
                }
            }
            elseif ($gagroup.name -match "Bitbucket") {
                Write-verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Checking archival status from Bitbucket" -f "")

            }
            elseif ($gagroup.name -match "Insight") {
                Write-verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Checking archival status Insight (?)" -f "")

            }
            else {
                Write-verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Unable to check archival status" -f "")
            }
        }
        $archivalstop = $stopwatch.ElapsedMilliseconds
        #endregion

        #TODO: Add project lead to owner group. If user is not valid, check if all the project users have same manager and if they do, add that manager as owner. Otherwise, don't process.

        $adwarestart = $stopwatch.ElapsedMilliseconds
        if ($createAdwareGroups.IsPresent) {
            Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))]     Ensuring presense of ADWARE group   {0,-$groupnamemax}  in $adwareGroupOU" -f $newname)
            If ($PSCmdlet.ShouldProcess("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] -- Creating group $($gagroup.name), if it doesn't exists", $gagroup.name, "Create new group, if it doesn't exist yet")) {
                $createdAdwaregroups.Add($(invoke-command -session $adwaresession -ScriptBlock {
                            if ($null -eq $(Get-ADGroup -SearchBase $Using:adwareGroupOU -Filter "Name -eq '$(($Using:gagroup).name))'")) {
                                try {
                                    New-ADGroup -Name $Using:newname -SamAccountName ($Using:gagroup).name -DisplayName ($Using:gagroup).name -GroupCategory Security -GroupScope Global -Description "Jira sync group, should be empty" -Path $Using:adwareGroupOU -PassThru
                                }
                                catch {}
                            }
                        })) | Out-Null
            }
        }
        $adwarestop = $stopwatch.ElapsedMilliseconds
        #region Populate variables: group membership lookup table and CSVs
        Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Populating group members" -f "")
        $memberpopulatestart = $stopwatch.ElapsedMilliseconds
        $members = $groupmembermap.($gagroup.name) | ` # The hashtable key is global.ad group name
        Foreach-Object -Process {
            # It's values are output of Get-ADGroupMember - Distinguishedname is the best available field
            # Usermap is another hashtable, which has Global.ad distinguihedname as key and Knowit UPN as value
            if ($null -ne $usermap.($_.DistinguishedName)) {
                [PSCustomObject]@{
                    name   = $newname
                    member = $usermap.($_.DistinguishedName)
                }
            }
        }
        $memberpopulatestop = $stopwatch.ElapsedMilliseconds
        <# Default owners not in use currently
        # Handle default owners
        if ($members.count -eq 0 -and $newname -match "^owner-") {
            $usedDefaultOwners = $true
            $members = $defaultOwnersMembers | Foreach-Object {
                [PSCustomObject]@{
                    name   = $newname
                    member = $_
                }
            }
        }
        # #>
        Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Populating group data" -f "")
        $groups = [PSCustomObject]@{
            Name        = $newname
            Description = $gagroup.description
        }
        Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Populating lookup table" -f "")
        $lookup.$newname = $members.member
        Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Adding data to output array" -f "")
        $CSVs.Add([PSCustomObject]@{
                NewGroup   = $groups
                NewMembers = $members
            }) | Out-Null
        if ($gagroup.name -notmatch "^App_") {
            Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,14} - Doing dirty owner-hack for special group" -f "")
            # Dirty hack for special groups
            $hackmembers = $groupmembermap.($gagroup.name) | `
                Foreach-Object -Process {
                if ($null -ne $usermap.($_.DistinguishedName)) {
                    [PSCustomObject]@{
                        name   = "owner-$newname"
                        member = $usermap.($_.DistinguishedName)
                    }
                }
            }
            $hackgroups = [PSCustomObject]@{
                Name        = $newname
                Description = $gagroup.description
            }
            $lookup."owner-$newname" = $hackmembers.member
            $CSVs.Add([PSCustomObject]@{
                    NewGroup   = $hackgroups
                    NewMembers = $hackmembers
                }) | Out-Null
        }
        Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] {0,4} [[ Perf metrics: Archival check: {1,4}ms, ADWARE-groups: {2,4}ms, Member populating: {3,4}ms ]]$(if($isOwnerGroup){"[Used default owner? $($usedDefaultOwners -eq $true)]"})" -f "", ($archivalstop - $archivalstart), ($adwarestop - $adwarestart), ($memberpopulatestop - $memberpopulatestart))
        #endregion
    }
}
$stopwatch.Stop()
$perfmetrics.DataCombine = $stopwatch.Elapsed
$stopwatch.Restart()
#endregion

#region Handle Jira username changing
$jiraOverlap = [System.Collections.ArrayList]@()
if ($changeJiraUsernames.IsPresent) {
    Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Changing the Jira usernames"
    $users | Where-Object { $_.KnowitUPN -ne $null } | ForEach-Object -Process {
        Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - $($_.GAUser.SamAccountName) to $($_.KnowitUPN)"
        If ($PSCmdlet.ShouldProcess("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] -- Changing Jira username $($_.GAUser.SamAccountName) to $($_.KnowitUPN)", $_.GAUser.SamAccountName, "Change usernme to $($_.KnowitUPN)")) {
            $result = $exists = $overlapped = ""
            $tries = 0
            do {
                $failed = $false

                #region Handle overlap - check if destination user exists already and rename if it is. And if there's something super odd and even renamed user exists already, do some tricks until renamed or tired 3 times.
                $overlap = $_.KnowitUPN
                $innertries = 0
                do {
                    $innerfailed = $false
                    try {
                        $exists = Invoke-RestMethod -Uri "https://$jirabaseurl/rest/api/2/user?username=$($_.KnowitUPN)" -Headers @{Authorization = "Bearer $jirapat" } -Method Get -ContentType "application/json" -ErrorVariable checkerror -verbose:$false
                    }
                    catch {
                        if ($_.exception.response.StatusCode -eq "NotFound") {
                            # Expected, continue
                            $exists = $null
                        }
                        else {
                            if ($null -eq $(try { $checkerror.message | ConvertFrom-Json -ErrorAction stop }catch {})) {
                                Write-Warning "Catched error when checking existence of destination user but message is not jSON! Exception: $($_.Exception.Message)"
                            }
                            else {
                                $errmsg = $checkerror.message | ConvertFrom-Json
                                if ($errmsg.errormessages -match "The user named '[a-zA-Z0-9.-_@]+' does not exist") {
                                    # This is expexted
                                    $exists = $null
                                }
                                else {
                                    Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] -! Destination user exists already, prefixing it with overlap-_-"
                                }
                            }
                        }
                    }
                    if ($null -ne $exists) {
                        if ($exists.key -eq $_.GAUser.SamAccountName) {
                            Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] -- key equals to old username, user processed correctly already."
                            return
                        }
                        else {
                            $overlap = "overlap-_-$overlap"
                            try {
                                $overlapped = Invoke-RestMethod -Uri "https://$jirabaseurl/rest/api/2/user?username=$($_.KnowitUPN)" -Headers @{Authorization = "Bearer $jirapat" } -Method Put -Body $(@{"name" = $overlap; "emailAddress" = $overlap } | ConvertTo-Json) -ContentType "application/json" -ErrorVariable overlaperror -verbose:$false
                            }
                            catch {
                                if ($null -eq $(try { $overlaperror.message | ConvertFrom-Json -ErrorAction stop }catch {})) {
                                    $innerfailed = $true
                                    Write-Warning "Catched error when renaming destination user but message is not jSON! Exception:`n$($_.Exception.Message)"
                                }
                                else {
                                    $errmsg = $overlaperror.message | ConvertFrom-Json
                                    if ($errmsg.errors.username -eq "A user with that username already exists.") {
                                        # Silent retry
                                        $innerfailed = $true
                                        if ($innertries -ge 3) {
                                            Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] !! Prefixing to '$overlap' failed, Jira returned error.`nerrorMessages: $($errmsg.errorMessages -join ", ")`nerrors:$($errmsg.errors -join ", ")"
                                        }
                                    }
                                    else {
                                        Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] !! Prefixing to '$overlap' failed, Jira returned error.`nerrorMessages: $($errmsg.errorMessages -join ", ")`nerrors:$($errmsg.errors -join ", ")"
                                    }
                                }
                            }
                            if ($null -ne $overlapped.name) {
                                $jiraOverlap.Add($overlap) | Out-Null
                            }
                        }
                    }
                    $innertries++
                }while ($innerfailed -and $innertries -lt 4)
                if ($innerfailed) {
                    Write-Warning "Failed changing overlapping username '$($_.KnowitUPN) to '$overlap' after $innertries tries!"
                }
                #endregion

                try {
                    $result = Invoke-RestMethod -Uri "https://$jirabaseurl/rest/api/2/user?username=$($_.GAUser.SamAccountName)" -Headers @{Authorization = "Bearer $jirapat" } -Method Put -Body $(@{name = $_.KnowitUPN; "emailAddress" = $_.KnowitUser.mail } | ConvertTo-Json) -ContentType "application/json" -ErrorVariable changeerror -verbose:$false
                }
                catch {
                    if ($_.exception.response.StatusCode -eq "NotFound") {
                        Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] !! Failed, user not found. Continuing with next user"
                    }
                    else {
                        # UPN might have been changed to incorrect one already so double-checking
                        $failed = $true
                        if ($null -eq $(try { $changeerror.message | ConvertFrom-Json -ErrorAction stop }catch {})) {
                            Write-Warning "Catched error when renaming destination user but message is not jSON! Exception:`n$($_.Exception.Message)"
                        }
                        else {
                            $chngerrmsg = $changeerror.message | ConvertFrom-Json
                            Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] !! Failed, Jira returned error.`nerrorMessages: $($chngerrmsg.errorMessages -join ", ")`nerrors:$($chngerrmsg.errors -join ", ")"
                        }
                    }
                }
                if ($null -ne $result -and $result.name -ne $_.KnowitUPN) {
                    Write-Warning "Failed changing username of $($_.GAUser.SamAccountName) to $($_.KnowitUPN)! API returned $($result.name) as usernme."
                }
                $tries++
            }while ($failed -and $tries -lt 4)
            if ($failed) {
                Write-Warning "Failed changing username '$($_.GAUser.SamAccountName)' to '$($_.KnowitUPN)' after $tries tries!"
            }
        }
    }
}
$perfmetrics.JiraUsernameChange = $stopwatch.Elapsed
#endregion

#region Check the data coherency
Write-information "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Checking owner groups if there's empty ones"
$stopwatch.Restart()
# This *SHOULD* be empty, as it's handled in the main data processor already, hence, just passing this info to output array
$emptyowners = $CSVs.newgroup | ForEach-Object -Process {
    if ($_.name -match "^owner-.*") {
        Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Current: $($_.name) - count $($lookup.($_.name).count)"
        if ($lookup.($_.name).count -eq 0) {
            Write-information "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - Empty found: $($_.name)"
            $_.name
        }
    }
}

Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Generating and populating missing owner groups"
$missingowner = $CSVs.newgroup.name | ForEach-Object -Process { if ($_ -notmatch "^owner-.*" -and "owner-$_" -notin $CSVs.newgroup.name) { $_ } }

if ($null -eq $DefaultOwnersMembers) {
    $DefaultOwnersMembers = $defaultOwners.members | Foreach-Object {
        $user = $_
        $userobj = $users | FilterUPN -field DistinguishedName -array GAUser -string $user.DistinguishedName -multidimensional #Where-Object { $_.GAUser.DistinguishedName -eq $user.DistinguishedName }
        if ($null -ne $userobj.KnowitUser) {
            $userobj.KnowitUPN
        }
    }
}

foreach ($missing in $missingowner) {
    Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Current: $missing"
    $members = $defaultOwnersMembers | Foreach-Object {
        [PSCustomObject]@{
            name   = "owner-$missing"
            member = $_
        }
    }
    $lookup."owner-$missing" = $members.member
    $groups = [PSCustomObject]@{
        Name        = "owner-$missing"
        Description = ""
    }
    Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - Adding data to output array"
    $CSVs.Add([PSCustomObject]@{
            NewGroup   = $groups
            NewMembers = $members
        }) | Out-Null
}
$stopwatch.Stop()
$perfmetrics.DataCoherencyCheck = $stopwatch.Elapsed
$stopwatch.Restart(); $stopwatch.Stop()
#endregion


Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Data preparation done, took $([system.math]::round((New-TimeSpan $starttime (Get-Date)).TotalMinutes,2)) minutes. Closing DC connections"
Remove-PSSession -Session $gadsession -WhatIf:$false | Out-Null
Remove-PSSession -Session $adwaresession -WhatIf:$false | Out-Null

#region Ensure knowit.local group existence and memberships
if ($populateKnowitGroups.IsPresent) {
    Start-Sleep -Seconds 3
    Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Ensuring existence of knowit.local groups and group memberships, starting with owner-groups"
    $stopwatch.Restart()
    $createdKnowitGroups = [System.Collections.ArrayList]@()
    $extra = @{}
    # Apparently foreach is actually faster than Where-Object
    $ownergroups = $CSVs.NewGroup | Foreach-Object -Process { if ($_.name -match "^owner-") { $_ } }
    $normalgroups = $CSVs.NewGroup | Foreach-Object -Process { if ($_.name -notin $ownergroups.name) { $_ } }
    $orderedgroups = $ownergroups + $normalgroups
    :grouploop foreach ($group in $orderedgroups) {
        Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] $($group.name)$(if($null -ne $longGroupNameMap.($group.name)){" (Shortened to $($longGroupNameMap.($group.name)))"})"
        if ($group.name -notmatch $knowitlocalPrefix) {
            Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] '$($group.name)' doesn't match prefix '$knowitlocalPrefix'!? Skipping"
            continue
        }
        $outertries = 1
        :outercreate do {
            $outerfail = $false
            $groupfound = $true
            $membersfound = $true
            # Handle too long group names
            if ((($group.name -match "^owner-" -and $group.name.length -gt 64) -or ($group.name -notmatch "^owner-" -and $group.name.length -gt 58)) -and $null -eq $longGroupNameMap.($group.name)) {
                Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Group name '$($group.name)' too long and wasn't found from conversion map!"
                $groupname = $false
                continue grouploop
            }
            elseif ($null -ne $longGroupNameMap.($group.name)) {
                $groupname = $longGroupNameMap.($group.name)
            }
            else {
                $groupname = $group.name
            }
            # Check existence and query members if exists
            $knowitgroupquerystart = $stopwatch.ElapsedMilliseconds
            $adgroupquery = invoke-command -session $knowitsession -ScriptBlock {
                $err = $false
                try {
                    $group = Get-ADGroup ($using:groupname) -ErrorAction Stop
                }
                catch {
                    $err = $_
                }
                return [PSCustomObject]@{Group = $group; Error = $err }
            }

            if ($adgroupquery.Error -ne $false) {
                $groupfound = $false
            }
            else {
                $adgroup = $adgroupquery.Group
            }

            if ($groupfound) {
                $groupmemberquery = invoke-command -session $knowitsession -ScriptBlock {
                    $err = $false
                    try {
                        $members = Get-ADGroupMember ([string]$using:adgroup) -ErrorAction Stop | ForEach-Object { Get-ADUser $_ -ErrorAction Stop }
                    }
                    catch {
                        $err = $_
                    }
                    return [PSCustomObject]@{GroupMembers = $members; Error = $err }
                }
                if ($groupmemberquery.Error -ne $false) {
                    $membersfound = $false
                }
                else {
                    $groupmembers = $groupmemberquery.GroupMembers
                }
            }
            $knowitgroupquery = $stopwatch.ElapsedMilliseconds - $knowitgroupquerystart
            # Yeah, bit clunky way, I know.
            if (-not $groupfound) {
                #region Create and populate missing group
                Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - Creating missing group"
                $innertries = 1
                $adgroup = $null
                :innercreate do {
                    $innerfail = $false
                    if ($groupname -notmatch "^owner-") {
                        $ownergroupquery = invoke-command -session $knowitsession -ScriptBlock {
                            $err = $false
                            try {
                                $group = Get-ADGroup "owner-$($using:groupname)" -ErrorAction Stop
                            }
                            catch {
                                $err = $_
                            }
                            return [PSCustomObject]@{Group = $group; Error = $err }
                        }
                        if ($ownergroupquery.Error -ne $false) {
                            Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - failed to get owner-group 'owner-$groupname', try $innertries/3. Error: $($_.Exception.Message)"
                            $innerfail = $true
                            $adgroupowner = $null
                        }
                        else {
                            $adgroupowner = $ownergroupquery.Group
                        }

                        if ($null -ne $adgroupowner) {
                            $adgroupcreate = invoke-command -session $knowitsession -ScriptBlock {
                                $err = $false
                                try {
                                    $ownergroup = Get-ADGroup ($using:adgroupowner).DistinguishedName -ErrorAction Stop
                                    $newgroup = New-ADGroup -Name $using:groupname -Description ($using:group).Description -Path "OU=MOC-Atlassian,OU=Koncerngemensamt,OU=Knowit,DC=knowit,DC=local" -ManagedBy $ownergroup -GroupScope Global -GroupCategory Security -PassThru  -ErrorAction Stop
                                }
                                catch {
                                    $err = $_
                                }
                                return [PSCustomObject]@{NewGroup = $newgroup; Error = $err }
                            }
                        }
                        else {
                            Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - owner-group object null, not creating group '$groupname'. Please check warning above."
                        }

                        if ($adgroupcreate.Error -ne $false) {
                            Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - failed to create group '$groupname', try $innertries. Error: $($adgroupcreate.Error.Exception.Message)"
                            $innerfail = $true
                            $adgroup = $null
                        }
                        else {
                            $adgroup = $adgroupcreate.NewGroup
                        }
                    }
                    else {
                        $adgroupcreate = invoke-command -session $knowitsession -ScriptBlock {
                            $err = $false
                            try {
                                $newgroup = New-ADGroup -Name $using:groupname -Description ($using:group).Description -Path "OU=MOC-Atlassian,OU=Koncerngemensamt,OU=Knowit,DC=knowit,DC=local" -GroupScope Global -GroupCategory Security -PassThru -ErrorAction Stop
                            }
                            catch {
                                $err = $_
                            }
                            return [PSCustomObject]@{NewGroup = $newgroup; Error = $err }
                        }
                        if ($adgroupcreate.Error -ne $false) {
                            Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - failed to create group '$groupname', try $innertries. Error: $($adgroupcreate.Error.Exception.Message)"
                            $innerfail = $true
                            $adgroup = $null
                        }
                        else {
                            $adgroup = $adgroupcreate.NewGroup
                        }
                    }
                    $innertries++
                }while ($innerfail -and $innertries -lt 4)

                if ($null -ne $adgroup.name) {
                    $createdKnowitGroups.Add($adgroup.name) | Out-Null
                    Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - Populating $($($lookup.($group.name)).count) members"
                    # NOTE: $lookup.($group.name) on lines above and below with dot between group and name is intentional! The lookup doesn't take the too long group names into account, which $groupname does!
                    $start = $stopwatch.ElapsedMilliseconds
                    $queriedusers = $users | FilterUPN -field KnowitUPN -array $lookup.($group.name) #Where-Object { $_.KnowitUPN -in $lookup.($group.name) }
                    $queryperf = $stopwatch.ElapsedMilliseconds - $start
                    Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] -- Adding $(@($queriedusers).count) users to group $([string]$adgroup.name)"
                    if ($queriedusers.count -gt 0) {
                        $grouppopulating = invoke-command -session $knowitsession -ScriptBlock {
                            $VerbosePreference = $using:verbosepreference
                            Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] - Getting group"
                            $localgroup = Get-ADGroup -Identity ($Using:adgroup).DistinguishedName -ErrorVariable groupqueryerror
                            $adderrors = @{UsersNotFound = [System.Collections.ArrayList]@(); GroupError = $groupqueryerror; UserAddError = "" }
                            if ($null -eq $localgroup) {
                                Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] - Group not found, no point continuing. Error: $($groupqueryerror.Exception.Message)"
                            }
                            else {
                                Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] - Getting users"
                                $localusers = foreach ($user in ($using:queriedusers).KnowitUser) {
                                    Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] -- $($user.Name)"
                                    try {
                                        Get-ADUser -Identity $user.DistinguishedName -ErrorAction Stop
                                    }
                                    catch {
                                        Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] --- User not found, error: $($_.Exception.Message)"
                                        $null = $adderrors.UsersNotFound.Add([PSCustomObject]@{User = $user; Error = $_ })
                                    }
                                }
                                Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] - Adding $(@($localusers).count) users to the group"
                                if (@($localusers).count -gt 0) {
                                    try {
                                        Add-ADGroupMember -Identity $localgroup -Members $localusers -ErrorAction Stop
                                    }
                                    catch {
                                        Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] -- Failed to add users to the group, error: $($_.Exception.Message)"
                                        $adderrors.UserAddError = $_
                                    }
                                }
                            }
                            return [PSCustomObject]@{UsersAdded = @($localusers).count; Errors = $adderrors }
                        }
                    }
                }
                if (-not [string]::IsNullOrWhiteSpace($grouppopulating.Errors.GroupError) -or @($grouppopulating.Errors.UsersNotFound).count -ne 0 -or -not [string]::IsNullOrWhiteSpace($grouppopulating.Errors.UserAddErrors)) {
                    Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - failed to process group '$groupname', try $outertries/3. Please check warnings above."
                    $outerfail = $true
                }
                #endregion
            }
            else {
                #region Populate missing members of existing group
                Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - Group exists, ensuring memberships ($(@($groupmembers).count) / $(@($lookup.($group.name)).count) members, currently / in data)"
                $missingadded = 0
                $start = $stopwatch.ElapsedMilliseconds
                $queriedusers = foreach ($user in $lookup.($group.name)) {
                    if (-not $membersfound -or $user -notin $groupmembers.UserPrincipalName) {
                        $users | FilterUPN -field KnowitUPN -string $user #Where-Object { $_.KnowitUPN -eq $user }
                    }
                }
                $queryperf = $stopwatch.ElapsedMilliseconds - $start
                if ($queriedusers.count -gt 0) {
                    Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] -- Adding $(@($queriedusers).count) users to group $([string]$adgroup.name)"
                    $addtries = 0
                    do {
                        $addfail = $false
                        $missingadded = invoke-command -session $knowitsession -ScriptBlock {
                            $VerbosePreference = $using:verbosepreference
                            Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] - Getting group"
                            $localgroup = Get-ADGroup -Identity ($Using:adgroup).DistinguishedName -ErrorVariable groupqueryerror
                            $adderrors = @{UsersNotFound = [System.Collections.ArrayList]@(); GroupError = $groupqueryerror; UserAddError = "" }
                            if ($null -eq $localgroup) {
                                Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] - Group not found, no point continuing. Error: $($groupqueryerror.Exception.Message)"
                            }
                            else {
                                Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] - Getting users"
                                $localusers = foreach ($user in ($using:queriedusers).KnowitUser) {
                                    Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] -- $($user.Name)"
                                    try {
                                        Get-ADUser -Identity $user.DistinguishedName -ErrorAction Stop
                                    }
                                    catch {
                                        Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] --- User not found, error: $($_.Exception.Message)"
                                        $null = $adderrors.UsersNotFound.Add([PSCustomObject]@{User = $user; Error = $_ })
                                    }
                                }
                                Write-verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] - Adding $(@($localusers).count) users to the group"
                                if (@($localusers).count -gt 0) {
                                    try {
                                        Add-ADGroupMember -Identity $localgroup -Members $localusers -ErrorAction Stop
                                    }
                                    catch {
                                        Write-Warning "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))][$($env:COMPUTERNAME)] -- Failed to add users to the group, error: $($_.Exception.Message)"
                                        $adderrors.UserAddError = $_
                                    }
                                }
                            }

                            return [PSCustomObject]@{UsersAdded = @($localusers).count; Errors = $adderrors }
                        }
                        if (-not [string]::IsNullOrWhiteSpace($missingadded.Errors.GroupError) -or @($missingadded.Errors.UsersNotFound).count -ne 0 -or -not [string]::IsNullOrWhiteSpace($missingadded.Errors.UserAddErrors)) {
                            Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] -- Detected failures in group population, try $($addtries + 1)/4. Please check warnings above."
                            $addfail = $true
                        }
                        $addtries++
                        Write-Debug "In the end of populating missing users to existing group"
                    }while ($addfail -and $addtries -lt 4)
                    Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - Added $($missingadded.UsersAdded) missing members"
                }
                $extramembers = [System.Collections.ArrayList]@()
                foreach ($user in $groupmembers) {
                    if ($user.UserPrincipalName -notin $lookup.($group.name)) {
                        $extramembers.Add($user.UserPrincipalName) | Out-Null
                    }
                }
                if ($null -eq $extra.($group.name)) {
                    $extra += @{$group.name = $extramembers }
                }
                else {
                    $extra.($group.name) = $extramembers
                }
                Write-Verbose "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] - Detected $($extramembers.count) extra members"
                #endregion
            }
            $outertries++
        }while ($outerfail -and $innerfail -and $outertries -lt 4)
        Write-Verbose ("[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))]      [[ Perf metrics: querying from knowit.local: {0,4}ms, filtering missing users {1,4}ms ]]" -f $knowitgroupquery, $queryperf)
    }
}
$perfmetrics.PopulateGroups = $stopwatch.Elapsed
$stopwatch.Stop()
#endregion

$returndata = [PSCustomObject]@{
    CSVs                = $CSVs
    UserData            = $users
    UserDataWithGroups  = $userswithgroups
    GroupData           = $groupmemberships
    NoKnowit            = $noKnowit
    CreatedAdwaregroups = $createdAdwaregroups
    CreatedKnowitGroups = $createdKnowitGroups
    ExtraMembers        = $extra
    NewEmployees        = $newemployees
    LookupTable         = $lookup
    EmptyOwnersGroup    = $emptyowners
    MissingOwnersGroup  = $missingowner
    Cache               = $cache
    PerfMetrics         = $perfmetrics
    G                   = $g
    GroupMemberMap      = $groupmembermap
    UserMap             = $usermap
}

Remove-PSSession $knowitsession -WhatIf:$false | Out-Null

Write-Information "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] Done - Execution time: $([system.math]::round((New-TimeSpan $starttime (Get-Date)).TotalMinutes,2)) minutes"

Stop-Transcript | out-null

return $returndata
