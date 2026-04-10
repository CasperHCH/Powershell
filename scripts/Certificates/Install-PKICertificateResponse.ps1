<#
.SYNOPSIS
    Prepares and installs certificate responses for the offline PKI server workflow.

.DESCRIPTION
    This companion script supports the response side of the Install-PKICertificateServer.ps1 workflow.
    It can:
    1. Submit a CSR to a Microsoft CA and package the issued response files for transfer.
    2. Retrieve and package an already issued response by Request ID.
    3. Install a returned certificate response package on the target server.

    All audit and execution logs are written next to this script for portability.

.PARAMETER RequestFilePath
    Path to the CSR/request file (.req or .csr) created by Install-PKICertificateServer.ps1.

.PARAMETER RequestId
    Certificate Services Request ID to retrieve from the CA.

.PARAMETER ResponseInputPath
    Path to a response package (.zip) or certificate response file (.cer, .crt, .p7b, .p7c).

.PARAMETER CertificateAuthorityConfig
    CA configuration in certreq/certutil format, for example ServerName\Contoso Issuing CA.

.PARAMETER CertificateTemplate
    Optional certificate template name to pass during submission.

.PARAMETER IssuePendingRequest
    If the CA marks the request as pending and a Request ID is available, attempt to issue it automatically.

.PARAMETER OutputDirectory
    Directory for generated response files and packages. Defaults to the script directory.

.PARAMETER SkipChainImport
    Skip importing any CA certificate bundled in the response package during installation.

.EXAMPLE
    .\Install-PKICertificateResponse.ps1 -RequestFilePath "C:\Transfer\Company-Root-CA-CSR-20260410-150000.req" `
        -CertificateAuthorityConfig "CA-SERVER-01\Contoso Issuing CA" -CertificateTemplate "SubCA"

.EXAMPLE
    .\Install-PKICertificateResponse.ps1 -RequestId 42 -CertificateAuthorityConfig "CA-SERVER-01\Contoso Issuing CA"

.EXAMPLE
    .\Install-PKICertificateResponse.ps1 -ResponseInputPath "C:\Transfer\Company-Root-CA-Response-Package-20260410-151500.zip"

.NOTES
    Author: PowerShell Team
    Version: 1.0
    Security: This script performs certificate issuance and installation steps and should be code-signed.

    Suggested workflow:
    1. Run Install-PKICertificateServer.ps1 on the target server to generate the CSR.
    2. Transfer the CSR to the CA server and run this script with -RequestFilePath.
    3. Transfer the generated response package back to the target server.
    4. Run this script again on the target server with -ResponseInputPath.
#>

[CmdletBinding(DefaultParameterSetName='PrepareResponse', SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true, ParameterSetName='PrepareResponse', HelpMessage='Path to the CSR/request file')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [ValidatePattern('\.(req|csr)$', ErrorMessage='Request file must be .req or .csr format')]
    [string]$RequestFilePath,

    [Parameter(Mandatory=$true, ParameterSetName='RetrieveResponse', HelpMessage='Issued CA Request ID to retrieve')]
    [ValidateRange(1, 2147483647)]
    [int]$RequestId,

    [Parameter(Mandatory=$true, ParameterSetName='InstallResponse', HelpMessage='Path to the response package or certificate response')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [ValidatePattern('\.(zip|cer|crt|p7b|p7c)$', ErrorMessage='Response input must be .zip, .cer, .crt, .p7b, or .p7c format')]
    [string]$ResponseInputPath,

    [Parameter(Mandatory=$false, ParameterSetName='PrepareResponse', HelpMessage='CA configuration string such as Server\Issuing CA')]
    [Parameter(Mandatory=$false, ParameterSetName='RetrieveResponse', HelpMessage='CA configuration string such as Server\Issuing CA')]
    [ValidateNotNullOrEmpty()]
    [string]$CertificateAuthorityConfig,

    [Parameter(Mandatory=$false, ParameterSetName='PrepareResponse', HelpMessage='Optional certificate template to submit')]
    [ValidateNotNullOrEmpty()]
    [string]$CertificateTemplate,

    [Parameter(Mandatory=$false, ParameterSetName='PrepareResponse', HelpMessage='Automatically issue a pending request when possible')]
    [switch]$IssuePendingRequest,

    [Parameter(Mandatory=$false, HelpMessage='Directory for generated response files and packages')]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory = $PSScriptRoot,

    [Parameter(Mandatory=$false, ParameterSetName='InstallResponse', HelpMessage='Skip importing the bundled CA certificate')]
    [switch]$SkipChainImport
)

$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:AuditLogFile = Join-Path $script:ScriptPath 'ScriptAudit.log'
$script:ExecutionLogFile = Join-Path $script:ScriptPath 'ScriptExecution.log'
$script:RequestFilePath = $RequestFilePath
$script:RequestId = $RequestId
$script:ResponseInputPath = $ResponseInputPath
$script:CertificateAuthorityConfig = $CertificateAuthorityConfig
$script:CertificateTemplate = $CertificateTemplate
$script:IssuePendingRequest = $IssuePendingRequest
$script:OutputDirectory = $OutputDirectory
$script:SkipChainImport = $SkipChainImport

function Write-ScriptLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG', 'AUDIT')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory=$false)]
        [switch]$Sensitive,

        [Parameter(Mandatory=$false)]
        [string]$LogPath = $script:ExecutionLogFile
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$($script:SessionId)] [$Level] $Message"
    $fullLogEntry = "[$timestamp] [$($script:SessionId)] [$Level] [$env:USERNAME] $Message"

    if (-not $Sensitive) {
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARNING' { 'Yellow' }
            'AUDIT' { 'Cyan' }
            'DEBUG' { 'Gray' }
            default { 'White' }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    try {
        Add-Content -Path $LogPath -Value $fullLogEntry -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write log file: $($_.Exception.Message)"
    }
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Action,

        [Parameter(Mandatory=$false)]
        [string]$Target,

        [Parameter(Mandatory=$false)]
        [string]$Error,

        [Parameter(Mandatory=$false)]
        [hashtable]$AdditionalData
    )

    $auditEntry = @{
        Timestamp = Get-Date -Format 'o'
        SessionId = $script:SessionId
        Action = $Action
        User = $env:USERNAME
        Target = $Target
        Error = $Error
        ComputerName = $env:COMPUTERNAME
        ScriptName = $MyInvocation.ScriptName
        AdditionalData = $AdditionalData
    }

    $auditJson = $auditEntry | ConvertTo-Json -Compress -Depth 5
    Write-ScriptLog -Message $auditJson -Level 'AUDIT' -Sensitive -LogPath $script:AuditLogFile
}

function Test-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Prerequisite {
    Write-ScriptLog 'Validating prerequisites.'

    if (-not (Test-Administrator)) {
        Write-AuditLog -Action 'VALIDATION_FAILED' -Error 'Administrator privileges are required.'
        throw 'This script requires administrator privileges.'
    }

    foreach ($commandName in @('certreq.exe', 'certutil.exe')) {
        if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            Write-AuditLog -Action 'VALIDATION_FAILED' -Error "Required command not found: $commandName"
            throw "Required command not found: $commandName"
        }
    }

    if (-not (Test-Path -Path $script:OutputDirectory)) {
        Write-ScriptLog "Creating output directory: $script:OutputDirectory" -Level INFO
        New-Item -Path $script:OutputDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    Write-AuditLog -Action 'VALIDATION_PASSED' -Target $script:OutputDirectory
}

function Invoke-CertificateCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string[]]$Arguments
    )

    $output = & $FilePath @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE

    return [pscustomobject]@{
        Output = $output.Trim()
        ExitCode = $exitCode
    }
}

function Get-RequestIdFromOutput {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$CommandOutput
    )

    $requestMatch = [regex]::Match($CommandOutput, 'RequestId\s*[:=]\s*(\d+)', 'IgnoreCase')
    if ($requestMatch.Success) {
        return [int]$requestMatch.Groups[1].Value
    }

    $requestMatch = [regex]::Match($CommandOutput, 'Request\s*Id\s*[:=]\s*(\d+)', 'IgnoreCase')
    if ($requestMatch.Success) {
        return [int]$requestMatch.Groups[1].Value
    }

    return $null
}

function Get-ResponsePathSet {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BaseName
    )

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $responseDirectory = Join-Path $script:OutputDirectory "$BaseName-Response-$timestamp"
    $responseCertificatePath = Join-Path $responseDirectory "$BaseName-response.cer"
    $caCertificatePath = Join-Path $responseDirectory "$BaseName-ca.cer"
    $metadataPath = Join-Path $responseDirectory "$BaseName-response-metadata.json"
    $packagePath = Join-Path $script:OutputDirectory "$BaseName-Response-Package-$timestamp.zip"

    return [pscustomobject]@{
        Directory = $responseDirectory
        ResponseCertificatePath = $responseCertificatePath
        CACertificatePath = $caCertificatePath
        MetadataPath = $metadataPath
        PackagePath = $packagePath
    }
}

function Export-CACertificate {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CertificatePath,

        [Parameter(Mandatory=$false)]
        [string]$CAConfig
    )

    $arguments = @()
    if ($CAConfig) {
        $arguments += @('-config', $CAConfig)
    }
    $arguments += @('-ca.cert', $CertificatePath)

    if (-not $PSCmdlet.ShouldProcess($CertificatePath, 'Export issuing CA certificate')) {
        return $false
    }

    $commandResult = Invoke-CertificateCommand -FilePath 'certutil.exe' -Arguments $arguments
    if ($commandResult.ExitCode -ne 0 -or -not (Test-Path -Path $CertificatePath)) {
        Write-ScriptLog "Unable to export issuing CA certificate: $($commandResult.Output)" -Level WARNING
        Write-AuditLog -Action 'CA_CERT_EXPORT_SKIPPED' -Target $CertificatePath -Error $commandResult.Output
        return $false
    }

    Write-AuditLog -Action 'CA_CERT_EXPORTED' -Target $CertificatePath
    return $true
}

function Get-IssuedCertificateResponse {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [int]$IssuedRequestId,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$false)]
        [string]$CAConfig
    )

    $arguments = @()
    if ($CAConfig) {
        $arguments += @('-config', $CAConfig)
    }
    $arguments += @('-retrieve', $IssuedRequestId, $OutputPath)

    if (-not $PSCmdlet.ShouldProcess($OutputPath, "Retrieve issued certificate response for Request ID $IssuedRequestId")) {
        return $false
    }

    $commandResult = Invoke-CertificateCommand -FilePath 'certreq.exe' -Arguments $arguments
    if ($commandResult.ExitCode -ne 0 -or -not (Test-Path -Path $OutputPath)) {
        Write-AuditLog -Action 'RESPONSE_RETRIEVE_FAILED' -Target $OutputPath -Error $commandResult.Output -AdditionalData @{ RequestId = $IssuedRequestId }
        throw "Failed to retrieve issued response for Request ID $IssuedRequestId. $($commandResult.Output)"
    }

    Write-AuditLog -Action 'RESPONSE_RETRIEVED' -Target $OutputPath -AdditionalData @{ RequestId = $IssuedRequestId }
    return $true
}

function Submit-CertificateRequest {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputRequestFilePath,

        [Parameter(Mandatory=$true)]
        [pscustomobject]$ResponsePaths,

        [Parameter(Mandatory=$false)]
        [string]$CAConfig,

        [Parameter(Mandatory=$false)]
        [string]$TemplateName,

        [Parameter(Mandatory=$false)]
        [switch]$AutoIssuePending
    )

    $arguments = @('-submit')
    if ($CAConfig) {
        $arguments += @('-config', $CAConfig)
    }
    if ($TemplateName) {
        $arguments += @('-attrib', "CertificateTemplate:$TemplateName")
    }
    $arguments += @($InputRequestFilePath, $ResponsePaths.ResponseCertificatePath)

    if (-not $PSCmdlet.ShouldProcess($InputRequestFilePath, 'Submit CSR to certificate authority')) {
        return [pscustomobject]@{ RequestId = $null; ResponseReady = $false; CommandOutput = '' }
    }

    $commandResult = Invoke-CertificateCommand -FilePath 'certreq.exe' -Arguments $arguments
    $submittedRequestId = Get-RequestIdFromOutput -CommandOutput $commandResult.Output

    if ($commandResult.ExitCode -eq 0 -and (Test-Path -Path $ResponsePaths.ResponseCertificatePath)) {
        Write-AuditLog -Action 'REQUEST_SUBMITTED' -Target $InputRequestFilePath -AdditionalData @{ RequestId = $submittedRequestId; Template = $TemplateName }
        return [pscustomobject]@{ RequestId = $submittedRequestId; ResponseReady = $true; CommandOutput = $commandResult.Output }
    }

    $isPending = $commandResult.Output -match 'pending|taken under submission' -or $commandResult.ExitCode -eq 3
    if ($isPending -and $submittedRequestId) {
        Write-ScriptLog "Request $submittedRequestId is pending CA approval." -Level WARNING
        Write-AuditLog -Action 'REQUEST_PENDING' -Target $InputRequestFilePath -AdditionalData @{ RequestId = $submittedRequestId; Output = $commandResult.Output }

        if ($AutoIssuePending) {
            $issueResult = Confirm-PendingCertificateRequest -IssuedRequestId $submittedRequestId -CAConfig $CAConfig
            if ($issueResult) {
                Get-IssuedCertificateResponse -IssuedRequestId $submittedRequestId -OutputPath $ResponsePaths.ResponseCertificatePath -CAConfig $CAConfig | Out-Null
                return [pscustomobject]@{ RequestId = $submittedRequestId; ResponseReady = $true; CommandOutput = $commandResult.Output }
            }
        }

        return [pscustomobject]@{ RequestId = $submittedRequestId; ResponseReady = $false; CommandOutput = $commandResult.Output }
    }

    Write-AuditLog -Action 'REQUEST_SUBMISSION_FAILED' -Target $InputRequestFilePath -Error $commandResult.Output
    throw "Certificate request submission failed. $($commandResult.Output)"
}

function Confirm-PendingCertificateRequest {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [int]$IssuedRequestId,

        [Parameter(Mandatory=$false)]
        [string]$CAConfig
    )

    $arguments = @()
    if ($CAConfig) {
        $arguments += @('-config', $CAConfig)
    }
    $arguments += @('-resubmit', $IssuedRequestId)

    if (-not $PSCmdlet.ShouldProcess("Request ID $IssuedRequestId", 'Issue pending certificate request')) {
        return $false
    }

    $commandResult = Invoke-CertificateCommand -FilePath 'certutil.exe' -Arguments $arguments
    if ($commandResult.ExitCode -ne 0) {
        Write-AuditLog -Action 'REQUEST_ISSUE_FAILED' -Error $commandResult.Output -AdditionalData @{ RequestId = $IssuedRequestId }
        throw "Failed to issue pending request $IssuedRequestId. $($commandResult.Output)"
    }

    Write-AuditLog -Action 'REQUEST_ISSUED' -AdditionalData @{ RequestId = $IssuedRequestId }
    return $true
}

function Save-ResponseMetadataFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$MetadataPath,

        [Parameter(Mandatory=$true)]
        [hashtable]$Metadata
    )

    $Metadata | ConvertTo-Json -Depth 6 | Set-Content -Path $MetadataPath -Encoding UTF8
    Write-AuditLog -Action 'RESPONSE_METADATA_SAVED' -Target $MetadataPath
}

function New-ResponsePackage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [pscustomobject]$ResponsePaths,

        [Parameter(Mandatory=$true)]
        [hashtable]$Metadata
    )

    Save-ResponseMetadataFile -MetadataPath $ResponsePaths.MetadataPath -Metadata $Metadata

    if (-not $PSCmdlet.ShouldProcess($ResponsePaths.PackagePath, 'Create certificate response package')) {
        return $ResponsePaths.PackagePath
    }

    if (Test-Path -Path $ResponsePaths.PackagePath) {
        Remove-Item -Path $ResponsePaths.PackagePath -Force -ErrorAction Stop
    }

    Compress-Archive -Path (Join-Path $ResponsePaths.Directory '*') -DestinationPath $ResponsePaths.PackagePath -Force -ErrorAction Stop
    Write-AuditLog -Action 'RESPONSE_PACKAGE_CREATED' -Target $ResponsePaths.PackagePath
    return $ResponsePaths.PackagePath
}

function Import-CertificateChainFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CertificatePath
    )

    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertificatePath)
    $storeName = if ($certificate.Subject -eq $certificate.Issuer) { 'Root' } else { 'CA' }

    if (-not $PSCmdlet.ShouldProcess($CertificatePath, "Import certificate into LocalMachine\\$storeName")) {
        return
    }

    Import-Certificate -FilePath $CertificatePath -CertStoreLocation "Cert:\LocalMachine\$storeName" -ErrorAction Stop | Out-Null
    Write-AuditLog -Action 'CHAIN_CERT_IMPORTED' -Target $CertificatePath -AdditionalData @{ Store = $storeName }
}

function Install-CertificateResponse {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CertificateResponsePath
    )

    if (-not $PSCmdlet.ShouldProcess($CertificateResponsePath, 'Accept certificate response on the local machine')) {
        return
    }

    $commandResult = Invoke-CertificateCommand -FilePath 'certreq.exe' -Arguments @('-accept', $CertificateResponsePath)
    if ($commandResult.ExitCode -ne 0) {
        Write-AuditLog -Action 'RESPONSE_INSTALL_FAILED' -Target $CertificateResponsePath -Error $commandResult.Output
        throw "Failed to install certificate response. $($commandResult.Output)"
    }

    Write-AuditLog -Action 'RESPONSE_INSTALLED' -Target $CertificateResponsePath
}

function Get-InstallPayload {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputPath
    )

    $extension = [System.IO.Path]::GetExtension($InputPath)
    $workingDirectory = $null
    $responseCertificatePath = $null
    $caCertificatePath = $null

    if ($extension -ieq '.zip') {
        $workingDirectory = Join-Path $script:OutputDirectory ("Install-Response-$([guid]::NewGuid().ToString('N'))")
        New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Expand-Archive -Path $InputPath -DestinationPath $workingDirectory -Force
    } else {
        $workingDirectory = Split-Path -Parent $InputPath
    }

    $candidateFiles = Get-ChildItem -Path $workingDirectory -File -Recurse
    $responseCertificatePath = ($candidateFiles | Where-Object { $_.Extension -in '.cer', '.crt', '.p7b', '.p7c' -and $_.BaseName -match 'response' } | Select-Object -First 1).FullName

    if (-not $responseCertificatePath -and $extension -ne '.zip') {
        $responseCertificatePath = $InputPath
    }

    $caCertificatePath = ($candidateFiles | Where-Object { $_.Extension -in '.cer', '.crt' -and $_.BaseName -match '(^|-)ca($|-)' } | Select-Object -First 1).FullName

    if (-not $responseCertificatePath) {
        throw 'No certificate response file was found in the supplied input.'
    }

    return [pscustomobject]@{
        WorkingDirectory = $workingDirectory
        ResponseCertificatePath = $responseCertificatePath
        CACertificatePath = $caCertificatePath
        IsExpandedPackage = ($extension -ieq '.zip')
    }
}

function Invoke-PrepareResponseWorkflow {
    $requestBaseName = [System.IO.Path]::GetFileNameWithoutExtension($script:RequestFilePath)
    $responsePaths = Get-ResponsePathSet -BaseName $requestBaseName
    New-Item -Path $responsePaths.Directory -ItemType Directory -Force -ErrorAction Stop | Out-Null

    $submitResult = Submit-CertificateRequest -InputRequestFilePath $script:RequestFilePath -ResponsePaths $responsePaths -CAConfig $script:CertificateAuthorityConfig -TemplateName $script:CertificateTemplate -AutoIssuePending:$script:IssuePendingRequest

    if ($submitResult.ResponseReady) {
        Export-CACertificate -CertificatePath $responsePaths.CACertificatePath -CAConfig $CertificateAuthorityConfig | Out-Null

        $metadata = @{
            Mode = 'PrepareResponse'
            RequestFilePath = $script:RequestFilePath
            RequestId = $submitResult.RequestId
            ResponseCertificatePath = $responsePaths.ResponseCertificatePath
            CACertificatePath = if (Test-Path -Path $responsePaths.CACertificatePath) { $responsePaths.CACertificatePath } else { $null }
            CertificateAuthorityConfig = $script:CertificateAuthorityConfig
            Template = $script:CertificateTemplate
            CreatedAt = Get-Date -Format 'o'
        }

        $packagePath = New-ResponsePackage -ResponsePaths $responsePaths -Metadata $metadata

        Write-Host ''
        Write-Host 'Response package created successfully.' -ForegroundColor Green
        Write-Host "Request ID: $($submitResult.RequestId)" -ForegroundColor White
        Write-Host "Package:    $packagePath" -ForegroundColor Yellow
        Write-Host "Response:   $($responsePaths.ResponseCertificatePath)" -ForegroundColor Gray
        if (Test-Path -Path $responsePaths.CACertificatePath) {
            Write-Host "CA Cert:    $($responsePaths.CACertificatePath)" -ForegroundColor Gray
        }
        return
    }

    Write-Host ''
    Write-Host 'The CA accepted the request but did not issue a response file yet.' -ForegroundColor Yellow
    Write-Host "Request ID: $($submitResult.RequestId)" -ForegroundColor White
    Write-Host 'Approve or issue the request on the CA, then rerun this script with -RequestId to package the response.' -ForegroundColor White
}

function Invoke-RetrieveResponseWorkflow {
    $requestBaseName = "Request-$($script:RequestId)"
    $responsePaths = Get-ResponsePathSet -BaseName $requestBaseName
    New-Item -Path $responsePaths.Directory -ItemType Directory -Force -ErrorAction Stop | Out-Null

    Get-IssuedCertificateResponse -IssuedRequestId $script:RequestId -OutputPath $responsePaths.ResponseCertificatePath -CAConfig $script:CertificateAuthorityConfig | Out-Null
    Export-CACertificate -CertificatePath $responsePaths.CACertificatePath -CAConfig $script:CertificateAuthorityConfig | Out-Null

    $metadata = @{
        Mode = 'RetrieveResponse'
        RequestId = $script:RequestId
        ResponseCertificatePath = $responsePaths.ResponseCertificatePath
        CACertificatePath = if (Test-Path -Path $responsePaths.CACertificatePath) { $responsePaths.CACertificatePath } else { $null }
        CertificateAuthorityConfig = $script:CertificateAuthorityConfig
        CreatedAt = Get-Date -Format 'o'
    }

    $packagePath = New-ResponsePackage -ResponsePaths $responsePaths -Metadata $metadata

    Write-Host ''
    Write-Host 'Retrieved response package created successfully.' -ForegroundColor Green
    Write-Host "Request ID: $($script:RequestId)" -ForegroundColor White
    Write-Host "Package:    $packagePath" -ForegroundColor Yellow
}

function Invoke-InstallResponseWorkflow {
    $payload = Get-InstallPayload -InputPath $script:ResponseInputPath

    if (-not $script:SkipChainImport -and $payload.CACertificatePath) {
        Import-CertificateChainFile -CertificatePath $payload.CACertificatePath
    }

    Install-CertificateResponse -CertificateResponsePath $payload.ResponseCertificatePath

    Write-Host ''
    Write-Host 'Certificate response installed successfully.' -ForegroundColor Green
    Write-Host "Installed response: $($payload.ResponseCertificatePath)" -ForegroundColor Yellow
    if ($payload.CACertificatePath -and -not $script:SkipChainImport) {
        Write-Host "Imported CA cert:   $($payload.CACertificatePath)" -ForegroundColor Gray
    }
}

function Main {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host 'PKI Certificate Response Workflow' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''

    Write-ScriptLog 'Script execution started.'
    Write-AuditLog -Action 'SCRIPT_START' -Target $PSCmdlet.ParameterSetName -AdditionalData @{
        ParameterSet = $PSCmdlet.ParameterSetName
        OutputDirectory = $script:OutputDirectory
    }

    Test-Prerequisite

    switch ($PSCmdlet.ParameterSetName) {
        'PrepareResponse' {
            Invoke-PrepareResponseWorkflow
        }
        'RetrieveResponse' {
            Invoke-RetrieveResponseWorkflow
        }
        'InstallResponse' {
            Invoke-InstallResponseWorkflow
        }
        default {
            throw "Unsupported parameter set: $($PSCmdlet.ParameterSetName)"
        }
    }

    Write-ScriptLog 'Script execution completed successfully.'
    Write-AuditLog -Action 'SCRIPT_COMPLETE' -Target $PSCmdlet.ParameterSetName
}

Main