<#
.SYNOPSIS
    Validates autoload scripts for parser health, analyzer findings, and synopsis presence.

.DESCRIPTION
    Scans PowerShell scripts under the autoload folder and reports:
    - Parser errors
    - ScriptAnalyzer warnings/errors
    - Missing .SYNOPSIS in comment-based help

.PARAMETER Path
    Root path of the autoload folder to validate.

.PARAMETER FailOnWarning
    Return a non-zero exit code if any analyzer warning is found.

.EXAMPLE
    .\Test-AutoloadScripts.ps1

.EXAMPLE
    .\Test-AutoloadScripts.ps1 -FailOnWarning
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'autoload'),

    [Parameter(Mandatory = $false)]
    [switch]$FailOnWarning
)

if (-not (Test-Path -Path $Path -PathType Container)) {
    throw "Autoload path not found: $Path"
}

$files = Get-ChildItem -Path $Path -Filter '*.ps1' -File | Sort-Object Name
if (-not $files) {
    Write-Warning "No .ps1 files found under $Path"
    return
}

$issues = @()

foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null

    if ($parseErrors) {
        foreach ($err in $parseErrors) {
            $issues += [PSCustomObject]@{
                File     = $file.Name
                Type     = 'ParserError'
                Rule     = 'Parser'
                Line     = $err.Extent.StartLineNumber
                Message  = $err.Message
            }
        }
    }

    $analysis = Invoke-ScriptAnalyzer -Path $file.FullName -Severity Error, Warning
    foreach ($finding in $analysis) {
        $issues += [PSCustomObject]@{
            File     = $file.Name
            Type     = 'Analyzer'
            Rule     = $finding.RuleName
            Line     = $finding.Line
            Message  = $finding.Message
        }
    }

    $raw = Get-Content -Path $file.FullName -Raw
    if ($raw -notmatch '(?is)\.SYNOPSIS') {
        $issues += [PSCustomObject]@{
            File     = $file.Name
            Type     = 'Documentation'
            Rule     = 'MissingSynopsis'
            Line     = 1
            Message  = 'Missing .SYNOPSIS in comment-based help.'
        }
    }
}

if ($issues.Count -eq 0) {
    Write-Information "Autoload validation passed: no issues found in $($files.Count) script(s)." -InformationAction Continue
    return
}

$issues | Sort-Object File, Type, Line | Format-Table -AutoSize

$hasWarnings = $issues | Where-Object { $_.Type -eq 'Analyzer' -or $_.Type -eq 'ParserError' -or $_.Type -eq 'Documentation' }
if ($FailOnWarning -and $hasWarnings) {
    exit 1
}
