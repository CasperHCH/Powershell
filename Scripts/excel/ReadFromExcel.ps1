$excel = Import-Excel C:\temp\projectTest.xlsx

foreach ($e in $excel){
    if($e.'Issue count' -lt 10){
        $ProjectName = $e.Name
        $ProjectName
        $issuecount = $e.'Issue count'
        $issuecount
        $key = $e.Key
        $key
        $LeadName = $e.'Lead display name'
        $LeadName
        $email = $e.'Lead Email'
        $email
    }
}
