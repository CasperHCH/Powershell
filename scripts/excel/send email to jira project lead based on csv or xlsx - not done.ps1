<#
.SYNOPSIS
Creates or sends low-issue Jira project review notifications from Excel data.

.DESCRIPTION
Imports project ownership data from an Excel workbook, filters projects with a
low issue count, builds a review email for each project lead, and either
previews the notification or sends it using a supplied SMTP server.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$ExcelPath,

    [Parameter(Mandatory = $false)]
    [string]$WorksheetName,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100000)]
    [int]$MaximumIssueCount = 9,

    [Parameter(Mandatory = $false)]
    [datetime]$ResponseDeadline = (Get-Date).Date.AddDays(14),

    [Parameter(Mandatory = $false)]
    [string]$SmtpServer,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$FromAddress,

    [Parameter(Mandatory = $false)]
    [switch]$PreviewOnly
)

function Initialize-ImportExcelModule {
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Install-Module -Name ImportExcel -Scope CurrentUser -Force -Confirm:$false
    }

    Import-Module ImportExcel -ErrorAction Stop
}

function Get-NotificationBody {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LeadDisplayName,

        [Parameter(Mandatory = $true)]
        [string]$ProjectName,

        [Parameter(Mandatory = $true)]
        [string]$ProjectKey,

        [Parameter(Mandatory = $true)]
        [int]$IssueCount,

        [Parameter(Mandatory = $true)]
        [datetime]$Deadline
    )

    @"
<p>Dear $LeadDisplayName,</p>
<p>
The Jira administration team is reviewing projects with low activity. Project
<strong>$ProjectName</strong> currently has <strong>$IssueCount</strong> issues and appears to be a candidate for cleanup.
</p>
<p>Please confirm whether the project should remain active.</p>
<table border="1" cellpadding="6" cellspacing="0">
<tr><td>Project Lead</td><td>$LeadDisplayName</td></tr>
<tr><td>Project Name</td><td>$ProjectName</td></tr>
<tr><td>Project Key</td><td>$ProjectKey</td></tr>
<tr><td>Issue Count</td><td>$IssueCount</td></tr>
<tr><td>Response Deadline</td><td>$($Deadline.ToString('yyyy-MM-dd'))</td></tr>
</table>
<p>If we do not hear back before the deadline, the project may be scheduled for follow-up review.</p>
<p>Regards,<br />Jira Administration Team</p>
"@
}

function Send-ProjectLeadNotification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToAddress,

        [Parameter(Mandatory = $true)]
        [string]$FromAddress,

        [Parameter(Mandatory = $true)]
        [string]$SmtpServer,

        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$Body
    )

    $message = [System.Net.Mail.MailMessage]::new($FromAddress, $ToAddress)
    $message.Subject = $Subject
    $message.Body = $Body
    $message.IsBodyHtml = $true

    $smtpClient = [System.Net.Mail.SmtpClient]::new($SmtpServer)
    $smtpClient.Send($message)
}

if (-not $ExcelPath) {
    $ExcelPath = Read-Host "Enter path to Excel file with project data"
}

if (-not $ExcelPath) {
    $ExcelPath = "C:\temp\projectTest.xlsx"
    Write-Information "Using default file: $ExcelPath" -InformationAction Continue
}

if (-not (Test-Path $ExcelPath -PathType Leaf)) {
    throw "Excel file not found: $ExcelPath"
}

Initialize-ImportExcelModule

$importParameters = @{ Path = $ExcelPath }
if ($WorksheetName) {
    $importParameters.WorksheetName = $WorksheetName
}

$projectRows = @(Import-Excel @importParameters)
if ($projectRows.Count -eq 0) {
    throw "No records were imported from $ExcelPath"
}

$results = foreach ($project in $projectRows) {
    $issueCount = [int]$project.'Issue count'
    if ($issueCount -gt $MaximumIssueCount) {
        continue
    }

    $toAddress = [string]$project.'Lead Email'
    if ([string]::IsNullOrWhiteSpace($toAddress)) {
        continue
    }

    $leadDisplayName = [string]$project.'Lead display name'
    $projectName = [string]$project.Name
    $projectKey = [string]$project.Key
    $subject = "Project review required: $projectName ($projectKey)"
    $body = Get-NotificationBody -LeadDisplayName $leadDisplayName -ProjectName $projectName -ProjectKey $projectKey -IssueCount $issueCount -Deadline $ResponseDeadline

    if ($PreviewOnly -or [string]::IsNullOrWhiteSpace($SmtpServer) -or [string]::IsNullOrWhiteSpace($FromAddress)) {
        Write-Information "Preview only: $projectName -> $toAddress" -InformationAction Continue
        [pscustomobject]@{
            ProjectName = $projectName
            ProjectKey = $projectKey
            LeadEmail = $toAddress
            IssueCount = $issueCount
            DeliveryMode = 'Preview'
        }
        continue
    }

    if ($PSCmdlet.ShouldProcess($toAddress, "Send project review notification for $projectName")) {
        Send-ProjectLeadNotification -ToAddress $toAddress -FromAddress $FromAddress -SmtpServer $SmtpServer -Subject $subject -Body $body
    }

    [pscustomobject]@{
        ProjectName = $projectName
        ProjectKey = $projectKey
        LeadEmail = $toAddress
        IssueCount = $issueCount
        DeliveryMode = 'Sent'
    }
}

$results
