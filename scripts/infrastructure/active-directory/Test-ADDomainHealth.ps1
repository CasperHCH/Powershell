<#
.SYNOPSIS
    Performs Active Directory health validation from a manifest.

.DESCRIPTION
    This script validates a target Active Directory domain using the configured
    environment manifest. It checks module availability, domain and forest lookup,
    configured versus discovered domain controllers, DNS records, basic network
    reachability, SYSVOL availability, FSMO role exposure, time-service reachability,
    replication-service signals, and optional dcdiag and repadmin command results.

.PARAMETER ManifestPath
    Path to the infrastructure manifest PSD1 file.

.PARAMETER DomainControllerName
    Optional override list of domain controllers to validate instead of the manifest.

.PARAMETER SkipDiagnosticCommands
    Skip dcdiag and repadmin execution when only lightweight checks are desired.

.EXAMPLE
    .\Test-ADDomainHealth.ps1 -ManifestPath ..\config\Environment.lab.psd1

.EXAMPLE
    .\Test-ADDomainHealth.ps1 -ManifestPath ..\config\Environment.lab.psd1 -SkipDiagnosticCommands
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [string[]]$DomainControllerName,

    [Parameter(Mandatory = $false)]
    [switch]$SkipDiagnosticCommands
)

Set-StrictMode -Version Latest

. (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Infrastructure-Common.ps1')

$scriptLogPath = Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'
$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath
$configuredDomainControllers = @(
    if ($PSBoundParameters.ContainsKey('DomainControllerName')) {
        @($DomainControllerName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    else {
        @(
            $manifest.ActiveDirectory.DomainControllers |
                ForEach-Object { $_.ServerName } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }
)

$results = New-Object 'System.Collections.Generic.List[object]'
$domainName = $manifest.Organization.Domain
$forestName = $null
$domain = $null
$forest = $null
$discoveredDomainControllers = @()
$adModuleAvailable = [bool](Get-Command -Name Get-ADDomain -ErrorAction SilentlyContinue)
$results.Add((New-InfrastructureCheckResult -Name 'Active Directory module available' -Passed $adModuleAvailable -Severity 'Error' -Details 'Required for directory-aware health validation.'))

if ($adModuleAvailable) {
    try {
        $domain = Get-ADDomain -Identity $domainName -ErrorAction Stop
        $results.Add((New-InfrastructureCheckResult -Name 'Domain lookup succeeded' -Passed $true -Severity 'Info' -Target $domainName -Details "DistinguishedName: $($domain.DistinguishedName)"))
    }
    catch {
        $domain = $null
        $results.Add((New-InfrastructureCheckResult -Name 'Domain lookup succeeded' -Passed $false -Severity 'Error' -Target $domainName -Details $_.Exception.Message))
    }

    try {
        $forest = Get-ADForest -Identity $domainName -ErrorAction Stop
        $forestName = $forest.Name
        $results.Add((New-InfrastructureCheckResult -Name 'Forest lookup succeeded' -Passed $true -Severity 'Info' -Target $forest.Name -Details "RootDomain: $($forest.RootDomain)"))
    }
    catch {
        $forest = $null
        $results.Add((New-InfrastructureCheckResult -Name 'Forest lookup succeeded' -Passed $false -Severity 'Error' -Target $domainName -Details $_.Exception.Message))
    }

    try {
        $discoveredDomainControllers = @(
            Get-ADDomainController -Filter * -Server $domainName -ErrorAction Stop |
                Sort-Object -Property HostName
        )
        $results.Add((New-InfrastructureCheckResult -Name 'Discovered domain controllers' -Passed ($discoveredDomainControllers.Count -gt 0) -Severity 'Error' -Target $domainName -Details "Discovered $($discoveredDomainControllers.Count) domain controller(s)." -Data ($discoveredDomainControllers | Select-Object -ExpandProperty HostName)))
    }
    catch {
        $discoveredDomainControllers = @()
        $results.Add((New-InfrastructureCheckResult -Name 'Discovered domain controllers' -Passed $false -Severity 'Error' -Target $domainName -Details $_.Exception.Message))
    }
}
else {
    $results.Add((New-InfrastructureCheckResult -Name 'Domain lookup succeeded' -Passed $false -Severity 'Error' -Target $domainName -Details 'Skipped because the Active Directory module is unavailable.'))
    $results.Add((New-InfrastructureCheckResult -Name 'Forest lookup succeeded' -Passed $false -Severity 'Error' -Target $domainName -Details 'Skipped because the Active Directory module is unavailable.'))
    $results.Add((New-InfrastructureCheckResult -Name 'Discovered domain controllers' -Passed $false -Severity 'Error' -Target $domainName -Details 'Skipped because the Active Directory module is unavailable.'))
}

$discoveredNames = @(
    $discoveredDomainControllers |
        ForEach-Object {
            @($_.HostName, $_.Name) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }
) | ForEach-Object { $_.ToLowerInvariant() }

if (@($configuredDomainControllers).Count -gt 0) {
    $missingConfiguredDomainControllers = @(
        $configuredDomainControllers | Where-Object { $_.ToLowerInvariant() -notin $discoveredNames }
    )
    $results.Add((New-InfrastructureCheckResult -Name 'Configured domain controllers are discoverable' -Passed ($missingConfiguredDomainControllers.Count -eq 0) -Severity 'Warning' -Target $domainName -Details ($(if ($missingConfiguredDomainControllers.Count -eq 0) { 'All configured domain controllers were discovered in Active Directory.' } else { 'Missing from discovery: ' + ($missingConfiguredDomainControllers -join ', ') })) -Data $missingConfiguredDomainControllers))
}
else {
    $results.Add((New-InfrastructureCheckResult -Name 'Configured domain controllers are discoverable' -Passed $false -Severity 'Warning' -Target $domainName -Details 'No domain controllers were defined in the manifest or via parameter override.'))
}

if ($adModuleAvailable -and $null -ne $domain) {
    $resolveDnsNameAvailable = [bool](Get-Command -Name Resolve-DnsName -ErrorAction SilentlyContinue)
    if ($resolveDnsNameAvailable) {
        try {
            $soaRecord = Resolve-DnsName -Name $domainName -Type SOA -ErrorAction Stop
            $results.Add((New-InfrastructureCheckResult -Name 'DNS SOA record resolves' -Passed ($null -ne $soaRecord) -Severity 'Warning' -Target $domainName -Details 'The domain SOA record resolved successfully.'))
        }
        catch {
            $results.Add((New-InfrastructureCheckResult -Name 'DNS SOA record resolves' -Passed $false -Severity 'Warning' -Target $domainName -Details $_.Exception.Message))
        }

        try {
            $dcSrvRecords = @(Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$domainName" -Type SRV -ErrorAction Stop)
            $results.Add((New-InfrastructureCheckResult -Name 'Domain controller SRV records resolve' -Passed ($dcSrvRecords.Count -gt 0) -Severity 'Warning' -Target $domainName -Details "Resolved $($dcSrvRecords.Count) SRV record(s)." -Data ($dcSrvRecords | Select-Object -ExpandProperty NameTarget)))
        }
        catch {
            $results.Add((New-InfrastructureCheckResult -Name 'Domain controller SRV records resolve' -Passed $false -Severity 'Warning' -Target $domainName -Details $_.Exception.Message))
        }
    }
    else {
        $results.Add((New-InfrastructureCheckResult -Name 'DNS SOA record resolves' -Passed $false -Severity 'Warning' -Target $domainName -Details 'Skipped because Resolve-DnsName is unavailable.'))
        $results.Add((New-InfrastructureCheckResult -Name 'Domain controller SRV records resolve' -Passed $false -Severity 'Warning' -Target $domainName -Details 'Skipped because Resolve-DnsName is unavailable.'))
    }

    if ($null -ne $forest) {
        $fsmoRoles = @(
            @{ Name = 'PDC Emulator FSMO role exposed'; Value = $domain.PDCEmulator },
            @{ Name = 'RID Master FSMO role exposed'; Value = $domain.RIDMaster },
            @{ Name = 'Infrastructure Master FSMO role exposed'; Value = $domain.InfrastructureMaster },
            @{ Name = 'Schema Master FSMO role exposed'; Value = $forest.SchemaMaster },
            @{ Name = 'Domain Naming Master FSMO role exposed'; Value = $forest.DomainNamingMaster }
        )

        foreach ($role in $fsmoRoles) {
            $results.Add((New-InfrastructureCheckResult -Name $role.Name -Passed (-not [string]::IsNullOrWhiteSpace($role.Value)) -Severity 'Warning' -Target $domainName -Details ($(if (-not [string]::IsNullOrWhiteSpace($role.Value)) { $role.Value } else { 'The role holder could not be determined.' })) -Data $role.Value))
        }
    }
}

foreach ($domainController in $configuredDomainControllers) {
    $reachable = Test-Connection -ComputerName $domainController -Count 1 -Quiet -ErrorAction SilentlyContinue
    $results.Add((New-InfrastructureCheckResult -Name 'Domain controller reachable' -Passed ([bool]$reachable) -Severity 'Error' -Target $domainController -Details ($(if ($reachable) { 'ICMP reachability succeeded.' } else { 'Unable to reach the domain controller over ICMP.' }))))

    $sysvolAvailable = $false
    if ($reachable) {
        try {
            $sysvolAvailable = Test-Path -Path "\\$domainController\SYSVOL"
        }
        catch {
            $sysvolAvailable = $false
        }
    }

    $results.Add((New-InfrastructureCheckResult -Name 'SYSVOL share available' -Passed $sysvolAvailable -Severity 'Warning' -Target $domainController -Details ($(if ($reachable) { if ($sysvolAvailable) { 'SYSVOL share was accessible.' } else { 'SYSVOL share was not accessible.' } } else { 'Skipped because the domain controller was not reachable.' }))))

    $replicationSignalDetected = $false
    $replicationSignalDetails = 'Skipped because the domain controller was not reachable.'
    if ($reachable) {
        try {
            $replicationServices = @(
                Get-CimInstance -ClassName Win32_Service -ComputerName $domainController -Filter "Name='DFSR' OR Name='NtFrs'" -ErrorAction Stop
            )
            $runningService = @($replicationServices | Where-Object { $_.State -eq 'Running' } | Select-Object -First 1)[0]
            $replicationSignalDetected = $null -ne $runningService
            if ($replicationSignalDetected) {
                $replicationSignalDetails = "Replication service running: $($runningService.Name)"
            }
            elseif ($replicationServices.Count -gt 0) {
                $replicationSignalDetails = 'Replication services were found, but none were running.'
            }
            else {
                $replicationSignalDetails = 'No DFSR or NtFrs service was found on the target domain controller.'
            }
        }
        catch {
            $replicationSignalDetails = $_.Exception.Message
            $replicationSignalDetected = $false
        }
    }

    $results.Add((New-InfrastructureCheckResult -Name 'SYSVOL replication service detected' -Passed $replicationSignalDetected -Severity 'Warning' -Target $domainController -Details $replicationSignalDetails))

    if (-not $SkipDiagnosticCommands) {
        $dcdiagAvailable = [bool](Get-Command -Name dcdiag.exe -ErrorAction SilentlyContinue)
        if ($dcdiagAvailable) {
            $dcdiagOutput = & dcdiag.exe /test:Advertising /s:$domainController 2>&1 | Out-String
            $dcdiagPassed = $LASTEXITCODE -eq 0
            $results.Add((New-InfrastructureCheckResult -Name 'dcdiag advertising test passed' -Passed $dcdiagPassed -Severity 'Warning' -Target $domainController -Details ($dcdiagOutput.Trim())))
        }
        else {
            $results.Add((New-InfrastructureCheckResult -Name 'dcdiag advertising test passed' -Passed $false -Severity 'Warning' -Target $domainController -Details 'Skipped because dcdiag.exe is unavailable.'))
        }
    }
}

$timeServiceTarget = if ($null -ne $domain -and -not [string]::IsNullOrWhiteSpace($domain.PDCEmulator)) {
    $domain.PDCEmulator
}
elseif ($configuredDomainControllers.Count -gt 0) {
    $configuredDomainControllers[0]
}
else {
    $null
}

if (-not [string]::IsNullOrWhiteSpace($timeServiceTarget)) {
    $w32tmAvailable = [bool](Get-Command -Name w32tm.exe -ErrorAction SilentlyContinue)
    if ($w32tmAvailable) {
        $w32tmOutput = & w32tm.exe /query /status /computer:$timeServiceTarget 2>&1 | Out-String
        $w32tmPassed = $LASTEXITCODE -eq 0
        $results.Add((New-InfrastructureCheckResult -Name 'Time service status query succeeded' -Passed $w32tmPassed -Severity 'Warning' -Target $timeServiceTarget -Details ($w32tmOutput.Trim())))
    }
    else {
        $results.Add((New-InfrastructureCheckResult -Name 'Time service status query succeeded' -Passed $false -Severity 'Warning' -Target $timeServiceTarget -Details 'Skipped because w32tm.exe is unavailable.'))
    }
}
else {
    $results.Add((New-InfrastructureCheckResult -Name 'Time service status query succeeded' -Passed $false -Severity 'Warning' -Target $domainName -Details 'Skipped because no PDC emulator or configured domain controller target was available.'))
}

if (-not $SkipDiagnosticCommands) {
    $repadminAvailable = [bool](Get-Command -Name repadmin.exe -ErrorAction SilentlyContinue)
    if ($repadminAvailable) {
        $repadminOutput = & repadmin.exe /replsummary 2>&1 | Out-String
        $repadminPassed = $LASTEXITCODE -eq 0
        $results.Add((New-InfrastructureCheckResult -Name 'repadmin replication summary passed' -Passed $repadminPassed -Severity 'Warning' -Target $domainName -Details ($repadminOutput.Trim())))
    }
    else {
        $results.Add((New-InfrastructureCheckResult -Name 'repadmin replication summary passed' -Passed $false -Severity 'Warning' -Target $domainName -Details 'Skipped because repadmin.exe is unavailable.'))
    }
}

$failedChecks = @($results | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' })
$warningChecks = @($results | Where-Object { -not $_.Passed -and $_.Severity -eq 'Warning' })
$passedChecks = @($results | Where-Object Passed)
$overallStatus = if ($failedChecks.Count -gt 0) {
    'Failed'
}
elseif ($warningChecks.Count -gt 0) {
    'Warning'
}
else {
    'Healthy'
}

Write-InfrastructureAudit -Action 'AD_DOMAIN_HEALTH_VALIDATION' -Target $domainName -AdditionalData @{
    Environment = $manifest.Environment.Name
    OverallStatus = $overallStatus
    ConfiguredDomainControllerCount = @($configuredDomainControllers).Count
    DiscoveredDomainControllerCount = @($discoveredDomainControllers).Count
    FailedChecks = $failedChecks.Count
    WarningChecks = $warningChecks.Count
} -LogPath $scriptLogPath

$discoveredDomainControllerNames = @(
    $discoveredDomainControllers | ForEach-Object {
        if ($_ -is [string]) {
            $_
        }
        elseif ($null -ne $_.HostName) {
            $_.HostName
        }
        elseif ($null -ne $_.Name) {
            $_.Name
        }
    }
)

$summary = @{}
$summary['Environment'] = $manifest.Environment.Name
$summary['Domain'] = $domainName
$summary['Forest'] = $forestName
$summary['OverallStatus'] = $overallStatus
$summary['ConfiguredDomainControllers'] = @($configuredDomainControllers)
$summary['DiscoveredDomainControllers'] = @($discoveredDomainControllerNames)
$summary['TotalChecks'] = $results.Count
$summary['PassedChecks'] = @($passedChecks).Count
$summary['FailedChecks'] = @($failedChecks).Count
$summary['WarningChecks'] = @($warningChecks).Count
$summary['Checks'] = [object[]]$results.ToArray()

$summary