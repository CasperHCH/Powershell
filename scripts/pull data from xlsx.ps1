param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    [string]$SearchValue = "0",
    [int]$WorksheetIndex = 1
)

try {
    if (!(Test-Path $FilePath)) {
        throw "Excel file not found: $FilePath"
    }

    Write-Host "Opening Excel file: $FilePath" -ForegroundColor Cyan
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $workbook = $excel.Workbooks.Open($FilePath)
    $workSheet = $Workbook.Sheets.Item($WorksheetIndex)

    Write-Host "Worksheet: $($WorkSheet.Name)" -ForegroundColor Green

    $Found = $WorkSheet.Cells.Find($SearchValue)
    if ($Found) {
        $BeginAddress = $Found.Address(0,0,1,1)
        Write-Host "Found '$SearchValue' at address: $BeginAddress" -ForegroundColor Green

        $result = [pscustomobject]@{
            WorkSheet = $Worksheet.Name
            Column = $Found.Column
            Row = $Found.Row
            Text = $Found.Text
            Address = $BeginAddress
        }

        $result | Format-Table -AutoSize
    } else {
        Write-Host "Value '$SearchValue' not found in worksheet" -ForegroundColor Yellow
    }
} catch {
    Write-Error "Error processing Excel file: $($_.Exception.Message)"
} finally {
    if ($workbook) { $workbook.Close($false) }
    if ($excel) { $excel.Quit() }
    Write-Host "Excel application closed" -ForegroundColor Green
}
