<#
.SYNOPSIS
Exports SQL query results to an Excel workbook.

.DESCRIPTION
Runs a SQL query against the specified server and database using integrated
security, writes the result set to an Excel workbook via COM automation, and
autofits the resulting worksheet columns.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Query = 'SELECT name, create_date FROM sys.tables'
)

$connectionStringBuilder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new()
$connectionStringBuilder['Data Source'] = $ServerName
$connectionStringBuilder['Initial Catalog'] = $DatabaseName
$connectionStringBuilder['Integrated Security'] = $true

$connection = [System.Data.SqlClient.SqlConnection]::new($connectionStringBuilder.ConnectionString)
$command = [System.Data.SqlClient.SqlCommand]::new($Query, $connection)
$adapter = [System.Data.SqlClient.SqlDataAdapter]::new($command)
$dataTable = [System.Data.DataTable]::new()

$excel = $null
$workbook = $null
$worksheet = $null

try {
    $connection.Open()
    [void]$adapter.Fill($dataTable)

    if (-not $PSCmdlet.ShouldProcess($OutputPath, 'Write Excel export')) {
        return
    }

    if (Test-Path -Path $OutputPath) {
        Remove-Item -Path $OutputPath -Force
    }

    $excel = New-Object -ComObject Excel.Application
    $excel.DisplayAlerts = $false
    $workbook = $excel.Workbooks.Add()
    $worksheet = $workbook.Worksheets.Item(1)
    $worksheet.Name = 'Data'

    for ($columnIndex = 0; $columnIndex -lt $dataTable.Columns.Count; $columnIndex++) {
        $worksheet.Cells.Item(1, $columnIndex + 1) = $dataTable.Columns[$columnIndex].ColumnName
    }

    for ($rowIndex = 0; $rowIndex -lt $dataTable.Rows.Count; $rowIndex++) {
        for ($columnIndex = 0; $columnIndex -lt $dataTable.Columns.Count; $columnIndex++) {
            $worksheet.Cells.Item($rowIndex + 2, $columnIndex + 1) = $dataTable.Rows[$rowIndex][$columnIndex]
        }
    }

    $worksheet.UsedRange.EntireColumn.AutoFit() | Out-Null
    $workbook.SaveAs($OutputPath)

    [pscustomobject]@{
        OutputPath = $OutputPath
        RowCount = $dataTable.Rows.Count
        ColumnCount = $dataTable.Columns.Count
    }
}
finally {
    if ($workbook) {
        $workbook.Close($true)
    }
    if ($excel) {
        $excel.Quit()
    }

    foreach ($comObject in @($worksheet, $workbook, $excel)) {
        if ($comObject) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($comObject)
        }
    }

    $adapter.Dispose()
    $command.Dispose()
    $connection.Dispose()
}