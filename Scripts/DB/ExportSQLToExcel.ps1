param(
    [Parameter(Mandatory=$true)]
    [string]$ServerName,
    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    [string]$Query = "SELECT * FROM sys.tables"
)

#some variables
$serverName = $ServerName
$databaseName = $DatabaseName

#the save location for the new Excel file
$filepath = $FilePath

# Check if file exist, if it does, delete it
# File contains previous output of Project Statistics
$file = $FilePath
If(Test-Path $file) {
     Remove-Item -Path $file -Force
     Write-Host "Removed existing file: $file" -ForegroundColor Yellow
}
#create excel object

$excel = New-Object -ComObject Excel.Application
$workbook = $excel.Workbooks.add()
$worksheetA = $workbook.Worksheets.Add()

#create byUser worksheet
$sheet1 = $workbook.worksheets.Item(1)
$sheet1.name = "Data"

#create a Dataset to store the DataTable
$dataSet = new-object System.Data.DataSet

#create a Connection to the SQL Server database
$cn = new-object System.Data.SqlClient.SqlConnection
$query = "SELECT * FROM YourTable"

#Create a SQL Data Adapter to place the resultset into the DataSet
$dataAdapter = new-object  ($query, $cn)
$dataAdapter.Fill($dataSet) | Out-Null

#close the connection
$cn.Close()

$dataTable = new-object System.Data.DataTable
$dataTable = $dataSet.Tables[0]
#assign  column names
$sheet1.cells.item(1, 1) = "Column1"
$sheet1.cells.item(1, 2) = "Column2"
$sheet1.cells.item(1, 3) = "Column3"
$sheet1.cells.item(1, 4) = "Column4"
$sheet1.cells.item(1, 5) =
$sheet1.cells.item(1, 6) =
$sheet1.cells.item(1, 7) =

#iterate through every DataTable line item and insert to the Excel worksheete

##Note: starts at 2 as 1 is the column headers

$x=2

$dataTable | FOREACH-OBJECT{
$sheet1.cells.item($x, 1) =  $_.email_address
$sheet1.cells.item($x, 2) =  $_.Lead_Display_Name
$sheet1.cells.item($x, 3) =  $_.lower_user_name
$sheet1.cells.item($x, 4) =  $_.LEAD
$sheet1.cells.item($x, 5) =  $_.pname
$sheet1.cells.item($x, 6) =  $_.pkey
$sheet1.cells.item($x, 7) =  $_.Issue_Count
$x++
}

$range1 = $sheet1.UsedRange
$range1.EntireColumn.AutoFit()

#save excel worksbook
$excel.ActiveWorkbook.SaveAs("C:\temp\ExportedData.xlsx")
$excel.quit()
