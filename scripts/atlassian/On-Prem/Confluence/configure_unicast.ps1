

<#
.SYNOPSIS
    Configures Confluence clustering to use unicast instead of multicast.
.DESCRIPTION
    Parameterized, secure script to update tangosol-coherence-override.xml inside a Confluence JAR.
    - No hardcoded IPs, ports, or file paths.
    - Supports WhatIf for safe execution.
    - Audit logging and parameter validation included.
.PARAMETER JarPath
    Path to the Confluence JAR file to modify.
.PARAMETER ExtractPath
    Temporary extraction folder for JAR contents.
.PARAMETER Nodes
    Array of hashtables: -Nodes @(@{id="1"; address="192.168.1.101"; port="8088"}, @{id="2"; address="192.168.1.102"; port="8088"})
.PARAMETER CurrentNodeAddress
    Address of the current node. Must be a part of the Nodes array.
.PARAMETER CurrentNodePort
    Port of the current node. Must correspond to the port defined in the Nodes array.
.PARAMETER WhatIf
    Shows what would happen without making changes.
 .EXAMPLE
   Preview changes with WhatIf:

    .\configure_unicast.ps1 -JarPath "C:\Program Files\Atlassian\Confluence\confluence\WEB-INF\lib\confluence-x.y.jar" -ExtractPath "C:\Temp\confluence-jar" -Nodes $nodes -CurrentNodeAddress "192.168.1.101" -CurrentNodePort 8088 -WhatIf

 .EXAMPLE
    Configure for three nodes:

    $nodes = @(
        @{id="1"; address="10.0.0.1"; port="9000"}, # Node 1
        @{id="2"; address="10.0.0.2"; port="9000"}, # Node 2
        @{id="3"; address="10.0.0.3"; port="9000"}  # Node 3
    )

    .\configure_unicast.ps1 -JarPath "D:\Confluence\confluence-x.y.jar" -ExtractPath "D:\Temp\confluence-jar" -Nodes $nodes -CurrentNodeAddress "10.0.0.1" -CurrentNodePort 9000
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true, HelpMessage="Path to Confluence JAR file")]
    [ValidateScript({Test-Path $_})]
    [string]$JarPath,

    [Parameter(Mandatory=$true, HelpMessage="Temporary extraction folder")]
    [ValidateNotNullOrEmpty()]
    [string]$ExtractPath,

    [Parameter(Mandatory=$true, HelpMessage="Array of node definitions (id, address, port)")]
    [ValidateNotNullOrEmpty()]
    [array]$Nodes,

    [Parameter(Mandatory=$true, HelpMessage="Current node address")]
    [ValidatePattern('^([0-9]{1,3}\.){3}[0-9]{1,3}$')]
    [string]$CurrentNodeAddress,

    [Parameter(Mandatory=$true, HelpMessage="Current node port")]
    [ValidateRange(1,65535)]
    [int]$CurrentNodePort
)

function Write-AuditLog {
    param(
        [string]$Action,
        [string]$Target,
        [string]$User = $env:USERNAME,
        [string]$Error,
        [hashtable]$AdditionalData
    )
    $auditEntry = @{
        Timestamp = Get-Date -Format "o"
        Action = $Action
        User = $User
        Target = $Target
        Error = $Error
        ComputerName = $env:COMPUTERNAME
        ScriptName = $MyInvocation.ScriptName
        AdditionalData = $AdditionalData
    }
    $auditJson = $auditEntry | ConvertTo-Json -Compress
    Add-Content -Path (Join-Path $PSScriptRoot "configure_unicast_audit.log") -Value $auditJson
}

if ($PSCmdlet.ShouldProcess($JarPath, "Configure unicast clustering")) {
    try {
        # Create extraction directory
        New-Item -ItemType Directory -Force -Path $ExtractPath | Out-Null

        # Extract the JAR file
        Expand-Archive -Path $JarPath -DestinationPath $ExtractPath -Force

        # Define the path to the override XML file
        $overrideXmlPath = Join-Path $ExtractPath "tangosol-coherence-override.xml"
        if (!(Test-Path $overrideXmlPath)) {
            throw "Override XML not found at $overrideXmlPath"
        }

        # Load the XML content
        [xml]$xml = Get-Content $overrideXmlPath

        # Comment out the multicast listener block
        $multicastNode = $xml.configuration."multicast-listener"
        if ($multicastNode) {
            $comment = $xml.CreateComment($multicastNode.OuterXml)
            $xml.configuration.RemoveChild($multicastNode) | Out-Null
            $xml.configuration.AppendChild($comment) | Out-Null
        }

        # Create unicast listener block
        $unicastNode = $xml.CreateElement("unicast-listener")
        $wellKnownAddresses = $xml.CreateElement("well-known-addresses")

        foreach ($node in $Nodes) {
            $socketAddress = $xml.CreateElement("socket-address")
            $socketAddress.SetAttribute("id", $node.id)

            $addressElement = $xml.CreateElement("address")
            $addressElement.InnerText = $node.address
            $socketAddress.AppendChild($addressElement) | Out-Null

            $portElement = $xml.CreateElement("port")
            $portElement.InnerText = $node.port
            $socketAddress.AppendChild($portElement) | Out-Null

            $wellKnownAddresses.AppendChild($socketAddress) | Out-Null
        }

        $unicastNode.AppendChild($wellKnownAddresses) | Out-Null

        # Define current node address and port
        $currentAddress = $xml.CreateElement("address")
        $currentAddress.InnerText = $CurrentNodeAddress
        $unicastNode.AppendChild($currentAddress) | Out-Null

        $currentPort = $xml.CreateElement("port")
        $currentPort.InnerText = $CurrentNodePort
        $unicastNode.AppendChild($currentPort) | Out-Null

        # Append unicast listener to configuration
        $xml.configuration.AppendChild($unicastNode) | Out-Null

        # Save the modified XML
        $xml.Save($overrideXmlPath)

        # Repackage the JAR file
        Compress-Archive -Path (Join-Path $ExtractPath '*') -DestinationPath $JarPath -Force

        Write-Host "✅ Unicast configuration applied successfully." -ForegroundColor Green
        Write-AuditLog -Action "UNICAST_CONFIG_SUCCESS" -Target $JarPath -AdditionalData @{Nodes=$Nodes;CurrentNodeAddress=$CurrentNodeAddress;CurrentNodePort=$CurrentNodePort}
    } catch {
        $sanitizedError = $_.Exception.Message -replace $JarPath, '[JAR_PATH]' -replace $ExtractPath, '[EXTRACT_PATH]'
        Write-Host "❌ Error: $sanitizedError" -ForegroundColor Red
        Write-AuditLog -Action "UNICAST_CONFIG_FAILED" -Target $JarPath -Error $_.Exception.Message -AdditionalData @{Nodes=$Nodes;CurrentNodeAddress=$CurrentNodeAddress;CurrentNodePort=$CurrentNodePort}
        throw
    }
} else {
    Write-Host "🔍 WhatIf: Would configure unicast clustering for $JarPath" -ForegroundColor Yellow
    Write-AuditLog -Action "WHATIF_UNICAST_CONFIG" -Target $JarPath -AdditionalData @{Nodes=$Nodes;CurrentNodeAddress=$CurrentNodeAddress;CurrentNodePort=$CurrentNodePort}
}
