$excel = New-Object -ComObject Excel.Application
$workbook = $excel.Workbooks.Open('C:\temp\Project Statistics 22-10-2019 13_26_38.xlsx')
$workSheet = $Workbook.Sheets.Item(1)
$WorkSheet.Name

$Found = $WorkSheet.Cells.Find('0')
$BeginAddress = $Found.Address(0,0,1,1)
$BeginAddress

[pscustomobject]@{
    WorkSheet = $Worksheet.Name
    Column = $Found.Column
    Row =$Found.Row
    Text = $Found.Text
    Address = $BeginAddress
}
