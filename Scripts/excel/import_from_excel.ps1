param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,

    [int]$IssueCountThreshold = 10
)

function Import-ProjectDataFromExcel {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [int]$Threshold = 10
    )

    try {
        if (-not (Test-Path $FilePath)) {
            throw "Excel file not found: $FilePath"
        }

        $excel = Import-Excel $FilePath

        $results = foreach ($e in $excel) {
            if ($e.'Issue count' -lt $Threshold) {
                [PSCustomObject]@{
                    ProjectName = $e.Name
                    IssueCount = $e.'Issue count'
                    Key = $e.Key
                    LeadName = $e.'Lead display name'
                    LeadEmail = $e.'Lead Email'
                }
            }
        }

        return $results

    } catch {
        Write-Error "Failed to import Excel data: $($_.Exception.Message)"
    }
}

# If running as script (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    Import-ProjectDataFromExcel -FilePath $FilePath -Threshold $IssueCountThreshold
}
