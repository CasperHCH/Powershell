<#
.SYNOPSIS
    Shared helpers for SCCM automation scripts in this folder.

.DESCRIPTION
    Provides common logging, audit, output path, object normalization,
    Configuration Manager module loading, site connection, and export helpers.

    This file is intended to be dot-sourced by SCCM automation scripts and is
    not designed to be run directly.
#>

Set-StrictMode -Version Latest

function Initialize-SccmScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$LogFileName,

        [Parameter(Mandatory = $false)]
        [switch]$EnableDebugLog,

        [Parameter(Mandatory = $false)]
        [string[]]$SensitiveTokens
    )

    $script:SessionId = ([guid]::NewGuid().ToString('N')).Substring(0, 8)
    $script:SccmScriptName = $ScriptName
    $script:SccmDebugEnabled = $EnableDebugLog.IsPresent
    $script:SccmSensitiveTokens = @($SensitiveTokens | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $resolvedLogFileName = if ([string]::IsNullOrWhiteSpace($LogFileName)) {
        '{0}.log' -f [System.IO.Path]::GetFileNameWithoutExtension($ScriptName)
    } else {
        $LogFileName
    }

    $script:LogFile = Join-Path -Path $PSScriptRoot -ChildPath $resolvedLogFileName

    return [pscustomobject]@{
        ScriptName = $script:SccmScriptName
        SessionId  = $script:SessionId
        LogFile    = $script:LogFile
    }
}

function ConvertTo-SccmArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return @()
    }

    return @($InputObject)
}

function Get-SccmCommandInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [switch]$Refresh
    )

    if ($null -eq $script:SccmCommandMetadataCache) {
        $script:SccmCommandMetadataCache = @{}
    }

    if (-not $Refresh -and $script:SccmCommandMetadataCache.ContainsKey($Name)) {
        return $script:SccmCommandMetadataCache[$Name]
    }

    $command = Get-Command -Name $Name -ErrorAction SilentlyContinue
    $script:SccmCommandMetadataCache[$Name] = $command
    return $command
}

function Invoke-SccmDryRunAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [scriptblock]$WriteLogScript
    )

    if ($DryRun) {
        if ($WriteLogScript) {
            & $WriteLogScript 'INFO' ("[DryRun] Would execute action: {0}" -f $Description)
        } elseif (Get-Command -Name 'Write-SccmLog' -ErrorAction SilentlyContinue) {
            Write-SccmLog -Level 'INFO' -Message ("[DryRun] Would execute action: {0}" -f $Description)
        }

        return [pscustomobject]@{
            Executed        = $false
            SkippedByDryRun = $true
        }
    }

    & $Action

    return [pscustomobject]@{
        Executed        = $true
        SkippedByDryRun = $false
    }
}

function Invoke-SccmCommandWithFallback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [scriptblock[]]$Attempts,

        [Parameter(Mandatory = $false)]
        [string]$ActionName = 'SCCM command',

        [Parameter(Mandatory = $false)]
        [scriptblock]$WriteLogScript
    )

    if ($null -eq $Attempts -or $Attempts.Count -eq 0) {
        return [pscustomobject]@{
            Success      = $false
            Result       = $null
            ErrorMessage = ("No fallback attempts were provided for {0}." -f $ActionName)
            Errors       = @()
        }
    }

    $errors = New-Object System.Collections.Generic.List[string]

    for ($attemptIndex = 0; $attemptIndex -lt $Attempts.Count; $attemptIndex++) {
        $attempt = $Attempts[$attemptIndex]
        if ($null -eq $attempt) {
            continue
        }

        try {
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'
            try {
                $result = & $attempt
            } finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

            return [pscustomobject]@{
                Success      = $true
                Result       = $result
                ErrorMessage = $null
                Errors       = @()
            }
        } catch {
            $attemptError = [string]$_.Exception.Message
            if (-not [string]::IsNullOrWhiteSpace($attemptError)) {
                [void]$errors.Add($attemptError)
            }

            $debugMessage = ("{0} fallback attempt {1}/{2} failed: {3}" -f $ActionName, ($attemptIndex + 1), $Attempts.Count, $attemptError)
            if ($WriteLogScript) {
                & $WriteLogScript 'DEBUG' $debugMessage
            } elseif (Get-Command -Name 'Write-SccmLog' -ErrorAction SilentlyContinue) {
                Write-SccmLog -Level 'DEBUG' -Message $debugMessage
            }
        }
    }

    $distinctErrors = @($errors | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    $errorMessage = if ($distinctErrors.Count -gt 0) {
        ("All {0} fallback attempts failed: {1}" -f $ActionName, ($distinctErrors -join ' | '))
    } else {
        ("All {0} fallback attempts failed." -f $ActionName)
    }

    return [pscustomobject]@{
        Success      = $false
        Result       = $null
        ErrorMessage = $errorMessage
        Errors       = $distinctErrors
    }
}

function Get-SccmObjectPropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames,

        [Parameter(Mandatory = $false)]
        [switch]$AsDateTime
    )

    if ($null -eq $InputObject) {
        return $null
    }

    foreach ($propertyName in $PropertyNames) {
        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            continue
        }

        try {
            $property = $InputObject.PSObject.Properties[$propertyName]
            if ($null -eq $property) {
                continue
            }

            $value = $property.Value
            if ($null -eq $value) {
                continue
            }

            if ($AsDateTime) {
                if ($value -is [datetime]) {
                    return $value
                }

                if ($value -is [string] -and -not [string]::IsNullOrWhiteSpace($value)) {
                    try {
                        return [datetime]::Parse($value)
                    } catch {
                        try {
                            return [System.Management.ManagementDateTimeConverter]::ToDateTime($value)
                        } catch {
                            Write-Debug -Message ("Get-SccmObjectPropertyValue could not convert [{0}] to DateTime." -f $value)
                        }
                    }
                }

                continue
            }

            if ($value -is [string]) {
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value.Trim()
                }

                continue
            }

            return $value
        } catch {
            Write-Debug -Message ("Get-SccmObjectPropertyValue failed to inspect property [{0}]." -f $propertyName)
        }
    }

    return $null
}

function Resolve-SccmDateTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [datetime]) {
        return $Value
    }

    if ($Value -is [string] -and -not [string]::IsNullOrWhiteSpace($Value)) {
        try {
            return [datetime]::Parse($Value)
        } catch {
            try {
                return [System.Management.ManagementDateTimeConverter]::ToDateTime($Value)
            } catch {
                Write-Debug -Message ("Resolve-SccmDateTime could not convert [{0}] to DateTime." -f $Value)
            }
        }
    }

    return $null
}

function Resolve-SccmOutputPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FileName,

        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory,

        [Parameter(Mandatory = $false)]
        [switch]$CreateDirectory
    )

    $baseDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        Join-Path -Path $PSScriptRoot -ChildPath 'output'
    } else {
        $OutputDirectory
    }

    if (-not [System.IO.Path]::IsPathRooted($baseDirectory)) {
        $baseDirectory = Join-Path -Path $PSScriptRoot -ChildPath $baseDirectory
    }

    if ($CreateDirectory -and -not (Test-Path -Path $baseDirectory)) {
        $null = New-Item -Path $baseDirectory -ItemType Directory -Force -WhatIf:$false
    }

    return Join-Path -Path $baseDirectory -ChildPath $FileName
}

function Get-SccmTimestampString {
    [CmdletBinding()]
    param()

    return (Get-Date -Format 'yyyyMMdd-HHmmss')
}

function Protect-SccmLogMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Message
    )

    $sanitizedMessage = [string]$Message

    foreach ($token in ConvertTo-SccmArray -InputObject $script:SccmSensitiveTokens) {
        if ([string]::IsNullOrWhiteSpace($token)) {
            continue
        }

        try {
            $sanitizedMessage = $sanitizedMessage -replace [regex]::Escape($token), '[REDACTED]'
        } catch {
            Write-Debug -Message ("Protect-SccmLogMessage could not sanitize one token value.")
        }
    }

    return $sanitizedMessage
}

function Write-SccmLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'AUDIT', 'DEBUG')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [switch]$Sensitive
    )

    if ($Level -eq 'DEBUG' -and -not $script:SccmDebugEnabled) {
        return
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $displayMessage = Protect-SccmLogMessage -Message $Message
    $displayEntry = ('[{0}] [{1}] [{2}] {3}' -f $timestamp, $script:SessionId, $Level, $displayMessage)

    if (-not $Sensitive) {
        Write-Information -MessageData $displayEntry -InformationAction Continue
    }

    $fileEntry = ('[{0}] [{1}] [{2}] [{3}] {4}' -f $timestamp, $script:SessionId, $Level, $env:USERNAME, [string]$Message)

    try {
        Add-Content -Path $script:LogFile -Value $fileEntry -ErrorAction Stop -WhatIf:$false
    } catch {
        $fallbackEntry = ('[{0}] [WARN] [LOGGING] Failed to write log entry: {1}' -f $timestamp, $_.Exception.Message)
        Write-Warning -Message $fallbackEntry
    }
}

function Write-SccmAuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [string]$Result,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage,

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalData
    )

    try {
        $auditObject = @{
            Timestamp      = (Get-Date).ToString('o')
            SessionId      = [string]$script:SessionId
            ScriptName     = [string]$script:SccmScriptName
            Action         = [string]$Action
            Target         = [string]$Target
            Result         = [string]$Result
            Error          = [string]$ErrorMessage
            User           = [string]$env:USERNAME
            ComputerName   = [string]$env:COMPUTERNAME
            AdditionalData = $AdditionalData
        }

        $auditMessage = $auditObject | ConvertTo-Json -Compress -Depth 6
        Write-SccmLog -Message ([string]$auditMessage) -Level 'AUDIT' -Sensitive
    } catch {
        $fallbackMessage = 'Audit logging failed for action [{0}]: {1}' -f [string]$Action, $_.Exception.Message
        Write-SccmLog -Message $fallbackMessage -Level 'WARN'
    }
}

function Import-SccmConfigurationManagerModule {
    [CmdletBinding()]
    param()

    $modulePath = $null

    if (-not [string]::IsNullOrWhiteSpace($env:SMS_ADMIN_UI_PATH)) {
        $modulePath = Join-Path -Path $env:SMS_ADMIN_UI_PATH -ChildPath '..\ConfigurationManager.psd1'
    }

    if ([string]::IsNullOrWhiteSpace($modulePath) -or -not (Test-Path -Path $modulePath)) {
        throw 'Configuration Manager console module was not found. Install the Configuration Manager console or run on a host where SMS_ADMIN_UI_PATH is available.'
    }

    Import-Module -Name $modulePath -ErrorAction Stop | Out-Null
}

function Resolve-SccmSiteCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SiteCode
    )

    if (-not [string]::IsNullOrWhiteSpace($SiteCode)) {
        return $SiteCode.Trim().ToUpperInvariant()
    }

    try {
        $provider = Get-CimInstance -Namespace 'root/SMS' -ClassName 'SMS_ProviderLocation' -ErrorAction Stop |
        Where-Object { $_.ProviderForLocalSite -eq $true } |
        Select-Object -First 1

        $resolvedSiteCode = Get-SccmObjectPropertyValue -InputObject $provider -PropertyNames @('SiteCode')
        if ([string]::IsNullOrWhiteSpace($resolvedSiteCode)) {
            throw 'Unable to determine SCCM site code from SMS_ProviderLocation.'
        }

        return $resolvedSiteCode.Trim().ToUpperInvariant()
    } catch {
        throw 'SiteCode was not provided and automatic discovery failed. Provide -SiteCode explicitly.'
    }
}

function Connect-SccmSite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SiteCode
    )

    Import-SccmConfigurationManagerModule

    $resolvedSiteCode = Resolve-SccmSiteCode -SiteCode $SiteCode
    $previousLocation = Get-Location
    $previousLocationPath = [string]$previousLocation.Path

    if (-not (Get-PSDrive -Name $resolvedSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        $siteDrive = Get-PSDrive -PSProvider CMSite -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $siteDrive) {
            throw ('Unable to find an SCCM CMSite PSDrive for site [{0}]. Open the Configuration Manager console on this host first or create the drive explicitly.' -f $resolvedSiteCode)
        }

        if ($siteDrive.Name -ne $resolvedSiteCode) {
            New-PSDrive -Name $resolvedSiteCode -PSProvider CMSite -Root $siteDrive.Root -Description 'SCCM site drive' -ErrorAction Stop | Out-Null
        }
    }

    Set-Location -Path ('{0}:' -f $resolvedSiteCode)

    return [pscustomobject]@{
        SiteCode             = $resolvedSiteCode
        PreviousLocation     = $previousLocation
        PreviousLocationPath = $previousLocationPath
    }
}

function Disconnect-SccmSite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $ConnectionContext
    )

    if ($null -eq $ConnectionContext) {
        return
    }

    $previousLocationPath = [string](Get-SccmObjectPropertyValue -InputObject $ConnectionContext -PropertyNames @('PreviousLocationPath', 'PreviousLocation'))
    if (-not [string]::IsNullOrWhiteSpace($previousLocationPath)) {
        try {
            Set-Location -Path $previousLocationPath -ErrorAction Stop
        } catch {
            Set-Location -Path $PSScriptRoot -ErrorAction SilentlyContinue
        }
    }
}

function Export-SccmData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Csv', 'Json')]
        [string]$Format = 'Csv'
    )

    $directoryPath = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($directoryPath) -and -not (Test-Path -Path $directoryPath)) {
        $null = New-Item -Path $directoryPath -ItemType Directory -Force -WhatIf:$false
    }

    switch ($Format) {
        'Json' {
            $InputObject | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8 -WhatIf:$false
        }
        default {
            $InputObject | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -WhatIf:$false
        }
    }

    return $Path
}

function Test-SccmLocalClient {
    [CmdletBinding()]
    param()

    try {
        $service = Get-Service -Name 'CcmExec' -ErrorAction Stop
        $client = Get-CimInstance -Namespace 'root/ccm' -ClassName 'SMS_Client' -ErrorAction Stop
    } catch {
        return $false
    }

    return ($null -ne $service -and $null -ne $client)
}
