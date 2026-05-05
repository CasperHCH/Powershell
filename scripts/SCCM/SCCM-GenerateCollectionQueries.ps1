Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"

# =========================
# CONFIG
# =========================
$SiteCode = "P03"
$OutputFolder = "C:\Users\admcach91\Desktop\MECM-Queries"
$JsonFile = Join-Path $OutputFolder "apps.json"
$QueryFolder = Join-Path $OutputFolder "Queries"

# Push location so we can restore the filesystem drive later
Push-Location
Set-Location "$SiteCode`:"

# =========================
# PREP FOLDERS
# =========================
# Use filesystem:: prefix to avoid running New-Item on the CM drive
New-Item -ItemType Directory -Force -Path "filesystem::$OutputFolder" | Out-Null
New-Item -ItemType Directory -Force -Path "filesystem::$QueryFolder"  | Out-Null

# =========================
# HELPER: Parse SDMPackageXML detection methods
# =========================
function Get-DetectionMethods {
    param(
        [string]$XmlString,
        [string]$AppName
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ([string]::IsNullOrWhiteSpace($XmlString)) {
        return $results
    }

    # Parse the XML safely
    try {
        $xml = [xml]$XmlString
    } catch {
        Write-Warning "  [XML PARSE ERROR] App: $AppName — $_"
        return $results
    }

    # Define the namespaces used in MECM SDMPackageXML
    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace("dcm", "http://schemas.microsoft.com/SystemsCenterConfigurationManager/2009/06/14/Rules")
    $ns.AddNamespace("ci", "http://schemas.microsoft.com/SystemsCenterConfigurationManager/2009/06/14/Rules")

    # SelectNodes wrapper that silently returns empty list on bad XPath
    function Select-Nodes ($doc, $xpath) {
        try { $doc.SelectNodes($xpath, $ns) }
        catch { @() }
    }

    # ------------------------------------------------------------------
    # 1. REGISTRY DETECTION
    #    Looks for RegistrySetting elements with a ValueName attribute
    # ------------------------------------------------------------------
    $regNodes = $xml.SelectNodes("//*[local-name()='RegistrySetting']")
    foreach ($node in $regNodes) {

        $valueName = $node.ValueName
        $keyPath = $node.Hive + "\" + $node.Key   # e.g. HKLM\SOFTWARE\...

        if (-not [string]::IsNullOrWhiteSpace($valueName)) {
            $results.Add([PSCustomObject]@{
                    DetectionType = "Registry"
                    Value         = $valueName
                    KeyPath       = $keyPath
                })
        } else {
            Write-Warning "  [REGISTRY] App: $AppName — found RegistrySetting node but ValueName is empty. KeyPath: $keyPath"
        }
    }

    # ------------------------------------------------------------------
    # 2. FILE DETECTION
    #    Looks for File elements with separate Path + FileName attributes
    # ------------------------------------------------------------------
    $fileNodes = $xml.SelectNodes("//*[local-name()='File']")
    foreach ($node in $fileNodes) {

        # MECM stores path and filename as separate attributes
        $fileName = $node.FileName
        $filePath = $node.Path

        # Fallback: some versions put the full path in a single Path attribute
        if ([string]::IsNullOrWhiteSpace($fileName) -and -not [string]::IsNullOrWhiteSpace($filePath)) {
            $fileName = Split-Path $filePath -Leaf
            $filePath = Split-Path $filePath -Parent
        }

        if (-not [string]::IsNullOrWhiteSpace($fileName)) {
            $results.Add([PSCustomObject]@{
                    DetectionType = "File"
                    FileName      = $fileName
                    FilePath      = $filePath
                })
        } else {
            Write-Warning "  [FILE] App: $AppName — found File node but could not extract FileName."
        }
    }

    # ------------------------------------------------------------------
    # 3. MSI / PRODUCT CODE DETECTION
    #    Looks for ProductCode elements (GUID format)
    # ------------------------------------------------------------------
    $msiNodes = $xml.SelectNodes("//*[local-name()='ProductCode']")
    foreach ($node in $msiNodes) {

        $productCode = $node.InnerText.Trim()

        if (-not [string]::IsNullOrWhiteSpace($productCode)) {
            $results.Add([PSCustomObject]@{
                    DetectionType = "MSI"
                    ProductCode   = $productCode
                    Name          = $AppName
                })
        }
    }

    # If no ProductCode nodes found but XML mentions MsiInstaller, add generic MSI entry
    if ($msiNodes.Count -eq 0 -and $XmlString -match "MsiInstaller") {
        $results.Add([PSCustomObject]@{
                DetectionType = "MSI"
                ProductCode   = $null
                Name          = $AppName
            })
    }

    # ------------------------------------------------------------------
    # 4. POWERSHELL / SCRIPT DETECTION
    #    Looks for Script or EnhancedDetectionMethod elements
    # ------------------------------------------------------------------
    $scriptNodes = $xml.SelectNodes("//*[local-name()='ScriptDetectionMethod' or local-name()='EnhancedDetectionMethod']")
    foreach ($node in $scriptNodes) {

        $scriptBody = $node.SelectSingleNode(".//*[local-name()='ScriptBody']")?.InnerText
        $scriptType = $node.SelectSingleNode(".//*[local-name()='ScriptType']")?.InnerText

        $results.Add([PSCustomObject]@{
                DetectionType = "PowerShellScript"
                ScriptType    = if ($scriptType) { $scriptType } else { "Unknown" }
                Name          = $AppName
                # Store a short excerpt so you know what the script checks
                ScriptExcerpt = if ($scriptBody) { $scriptBody.Substring(0, [Math]::Min(200, $scriptBody.Length)).Trim() } else { $null }
            })
    }

    return $results
}

# =========================
# STEP 1 — BUILD CATALOG FROM MECM
# =========================
Write-Host "`nBuilding application catalog from MECM..." -ForegroundColor Cyan

$apps = Get-CMApplication
$catalog = [System.Collections.Generic.List[PSCustomObject]]::new()
$i = 0

foreach ($app in $apps) {

    $i++
    Write-Progress -Activity "Processing apps" -Status "$($app.LocalizedDisplayName)" -PercentComplete (($i / $apps.Count) * 100)

    $dts = Get-CMDeploymentType -ApplicationName $app.LocalizedDisplayName -ErrorAction SilentlyContinue
    $methods = [System.Collections.Generic.List[PSCustomObject]]::new()

    if (-not $dts) {
        Write-Warning "  [NO DTs] App: $($app.LocalizedDisplayName) — no deployment types found."
    }

    foreach ($dt in $dts) {
        $parsed = Get-DetectionMethods -XmlString $dt.SDMPackageXML -AppName $app.LocalizedDisplayName
        foreach ($p in $parsed) { $methods.Add($p) }
    }

    # Deduplicate: same DetectionType + same key identifier
    $unique = $methods | Sort-Object DetectionType, Value, FileName, ProductCode -Unique

    $catalog.Add([PSCustomObject]@{
            Name             = $app.LocalizedDisplayName
            Manufacturer     = $app.Manufacturer
            Version          = $app.SoftwareVersion
            DetectionMethods = @($unique)   # force array even if single item
        })
}

Write-Progress -Activity "Processing apps" -Completed

# Export JSON — use filesystem:: to avoid CM drive issues
$catalog | ConvertTo-Json -Depth 8 | Out-File "filesystem::$JsonFile" -Encoding UTF8

Write-Host "JSON exported to: $JsonFile" -ForegroundColor Green

# Summary
$noMethods = @($catalog | Where-Object { $_.DetectionMethods.Count -eq 0 })
Write-Host "`nSummary:"
Write-Host "  Total apps processed : $($catalog.Count)"
Write-Host "  Apps with no methods : $($noMethods.Count)"
if ($noMethods.Count -gt 0) {
    Write-Host "  Apps missing methods :" -ForegroundColor Yellow
    $noMethods | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Yellow }
}

# =========================
# STEP 2 — GENERATE QUERY FILES
# =========================
Write-Host "`nGenerating query files..." -ForegroundColor Cyan

# Use $catalog directly — no need to re-read the JSON
foreach ($app in $catalog) {

    $safeName = ($app.Name -replace '[\\\/:*?"<>|]', '_')
    $filePath = Join-Path $QueryFolder "$safeName.txt"

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("====================================================")
    $lines.Add("APPLICATION : $($app.Name)")
    $lines.Add("MANUFACTURER: $($app.Manufacturer)")
    $lines.Add("VERSION     : $($app.Version)")
    $lines.Add("====================================================")
    $lines.Add("")

    if ($app.DetectionMethods.Count -eq 0) {
        $lines.Add("-- WARNING: No parseable detection methods found.")
        $lines.Add("-- Manual investigation required.")
        $lines.Add("")
    }

    foreach ($method in $app.DetectionMethods) {

        switch ($method.DetectionType) {

            "Registry" {
                $lines.Add("-- Registry Detection  (ValueName: $($method.Value))")
                $lines.Add(@"
select SMS_R_SYSTEM.ResourceID,
       SMS_R_SYSTEM.Name
from SMS_R_System
inner join SMS_G_System_REGISTRY
on SMS_G_System_REGISTRY.ResourceID = SMS_R_System.ResourceId
where SMS_G_System_REGISTRY.KeyPath like "%$($method.KeyPath)%"
and   SMS_G_System_REGISTRY.ValueName like "%$($method.Value)%"
"@)
                $lines.Add("")
                $lines.Add("----------------------------------------------------")
                $lines.Add("")
            }

            "File" {
                $lines.Add("-- File Detection  (File: $($method.FileName))")
                $lines.Add(@"
select SMS_R_SYSTEM.ResourceID,
       SMS_R_SYSTEM.Name
from SMS_R_System
inner join SMS_G_System_SoftwareFile
on SMS_G_System_SoftwareFile.ResourceID = SMS_R_System.ResourceId
where SMS_G_System_SoftwareFile.FileName = "$($method.FileName)"
"@)
                # Optionally filter by path too if we have it
                if (-not [string]::IsNullOrWhiteSpace($method.FilePath)) {
                    $lines.Add("-- NOTE: Expected path is: $($method.FilePath)")
                    $lines.Add("-- To filter by path add:")
                    $lines.Add("--   and SMS_G_System_SoftwareFile.FilePath like `"%$($method.FilePath -replace '\\','\\')%`"")
                }
                $lines.Add("")
                $lines.Add("----------------------------------------------------")
                $lines.Add("")
            }

            "MSI" {
                if ($method.ProductCode) {
                    $lines.Add("-- MSI Detection  (ProductCode: $($method.ProductCode))")
                    $lines.Add(@"
select SMS_R_SYSTEM.ResourceID,
       SMS_R_SYSTEM.Name
from SMS_R_System
inner join SMS_G_System_INSTALLED_SOFTWARE
on SMS_G_System_INSTALLED_SOFTWARE.ResourceID = SMS_R_System.ResourceId
where SMS_G_System_INSTALLED_SOFTWARE.ProductCode = "$($method.ProductCode)"
"@)
                } else {
                    # Fall back to ARP display name match
                    $lines.Add("-- MSI / ARP Detection  (no ProductCode — falling back to DisplayName)")
                    $lines.Add(@"
select SMS_R_SYSTEM.ResourceID,
       SMS_R_SYSTEM.Name
from SMS_R_System
inner join SMS_G_System_ADD_REMOVE_PROGRAMS
on SMS_G_System_ADD_REMOVE_PROGRAMS.ResourceID = SMS_R_System.ResourceId
where SMS_G_System_ADD_REMOVE_PROGRAMS.DisplayName like "%$($app.Name)%"
"@)
                }
                $lines.Add("")
                $lines.Add("----------------------------------------------------")
                $lines.Add("")
            }

            "PowerShellScript" {
                $lines.Add("-- PowerShell / Script Detection  (NOT convertible to WQL)")
                $lines.Add("-- Script type : $($method.ScriptType)")
                $lines.Add("-- Manual remediation required.")
                if ($method.ScriptExcerpt) {
                    $lines.Add("-- Script excerpt (first 200 chars):")
                    $lines.Add("--   $($method.ScriptExcerpt -replace "`n","  ")")
                }
                $lines.Add("")
                $lines.Add("----------------------------------------------------")
                $lines.Add("")
            }
        }
    }

    $lines | Out-File "filesystem::$filePath" -Encoding UTF8
    Write-Host "  Generated: $filePath"
}

Pop-Location   # Restore original drive/location

Write-Host "`nDONE — JSON + query files generated successfully." -ForegroundColor Green
