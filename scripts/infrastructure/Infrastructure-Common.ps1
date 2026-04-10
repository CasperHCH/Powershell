Set-StrictMode -Version Latest

function Write-InfrastructureLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG', 'AUDIT')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [string]$LogPath = (Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'),

        [Parameter(Mandatory = $false)]
        [switch]$Sensitive
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"

    if (-not $Sensitive) {
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARNING' { 'Yellow' }
            'AUDIT' { 'Cyan' }
            default { 'White' }
        }
        Write-Host $entry -ForegroundColor $color
    }

    Add-Content -Path $LogPath -Value $entry
}

function Write-InfrastructureAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalData,

        [Parameter(Mandatory = $false)]
        [string]$LogPath = (Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log')
    )

    $payload = @{
        Timestamp = Get-Date -Format 'o'
        Action = $Action
        User = $env:USERNAME
        ComputerName = $env:COMPUTERNAME
        Target = $Target
        AdditionalData = $AdditionalData
    }

    Write-InfrastructureLog -Message ($payload | ConvertTo-Json -Compress) -Level 'AUDIT' -LogPath $LogPath -Sensitive
}

function Import-InfrastructureManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path -Path $_ })]
        [string]$ManifestPath
    )

    $manifestExtension = [System.IO.Path]::GetExtension($ManifestPath)
    $manifest = $null

    switch ($manifestExtension.ToLowerInvariant()) {
        '.psd1' {
            $manifest = Import-PowerShellDataFile -Path $ManifestPath
        }
        '.ps1' {
            $manifest = & $ManifestPath
        }
        default {
            throw "Unsupported manifest format '$manifestExtension'. Use .psd1 or .ps1."
        }
    }

    if ($null -eq $manifest) {
        throw 'Manifest import returned no data.'
    }

    if (-not ($manifest -is [System.Collections.IDictionary])) {
        throw 'Manifest must return a hashtable or other IDictionary-compatible object.'
    }

    $requiredSections = 'Organization', 'Environment', 'ActiveDirectory', 'PKI', 'SCCM'

    foreach ($section in $requiredSections) {
        if (-not $manifest.ContainsKey($section)) {
            throw "Manifest is missing required section '$section'."
        }
    }

    return $manifest
}

function Test-InfrastructureAdministrator {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-InfrastructurePrerequisite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Test,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Severity = 'Error'
    )

    try {
        $passed = & $Test
    }
    catch {
        $passed = $false
    }

    [pscustomobject]@{
        Name = $Name
        Passed = [bool]$passed
        Severity = $Severity
    }
}

function New-InfrastructureCheckResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [bool]$Passed,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Severity = 'Info',

        [Parameter(Mandatory = $false)]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [string]$Details,

        [Parameter(Mandatory = $false)]
        [object]$Data
    )

    [pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Severity = $Severity
        Target = $Target
        Details = $Details
        Data = $Data
    }
}

function Invoke-InfrastructurePlanStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,

        [Parameter(Mandatory = $false)]
        [string]$LogPath = (Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log')
    )

    Write-InfrastructureLog -Message "Starting step: $Name" -LogPath $LogPath
    & $Action
    Write-InfrastructureLog -Message "Completed step: $Name" -LogPath $LogPath
}