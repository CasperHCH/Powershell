#some variables
$serverName = "miraclesql2012";
$databaseName = "'JIRA-DB-TEST-[MIR-TST-JIRA01]'";

#the save location for the new Excel file
$filepath = "C:\temp\Project-Statistics.xlsx";

# Check if file exist, if it does, delete it
# File contains previous output of Project Statistics
$file = "C:\temp\Project-Statistics.xlsx"
If(test-path $file)
{
     Remove-Item -Path $file -Recurse
}
#create excel object

$excel = New-Object -ComObject Excel.Application
$workbook = $excel.Workbooks.add()
$worksheetA = $workbook.Worksheets.Add()

#create byUser worksheet
$sheet1 = $workbook.worksheets.Item(1)
$sheet1.name = "Project-Statistics"
 
#create a Dataset to store the DataTable 
$dataSet = new-object "System.Data.DataSet" "Project-Statistics"
 
#create a Connection to the SQL Server database
$cn = new-object System.Data.SqlClient.SqlConnection "server=$serverName;database=$databaseName;Integrated Security=sspi"
$query= "SELECT us.email_address, MAX(us.display_name)Lead_Display_Name, us.lower_user_name, pr.LEAD, pr.pname, pr.pkey, count(ji.id)Issue_Count FROM jiraissue ji left join project pr on pr.id = ji.project left join cwd_user us on us.lower_user_name = pr.LEAD group by pr.pkey, us.email_address, pr.pname,us.lower_user_name, pr.LEAD;"

#Create a SQL Data Adapter to place the resultset into the DataSet
$dataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($query, $cn)
$dataAdapter.Fill($dataSet) | Out-Null

#close the connection
$cn.Close()
 
$dataTable = new-object "System.Data.DataTable" "Principals"
$dataTable = $dataSet.Tables[0]
#assign  column names
$sheet1.cells.item(1, 1) =  "Lead Email"
$sheet1.cells.item(1, 2) =  "Lead Display Name"
$sheet1.cells.item(1, 3) =  "Lead Username Lower Case"
$sheet1.cells.item(1, 4) =  "Lead Username"
$sheet1.cells.item(1, 5) =  "Project Name"
$sheet1.cells.item(1, 6) =  "Project Key"
$sheet1.cells.item(1, 7) =  "Issue Count"
 
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
$excel.ActiveWorkbook.SaveAs("$filepath ")
$excel.quit()