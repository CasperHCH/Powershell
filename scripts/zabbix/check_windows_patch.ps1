[CmdletBinding(DefaultParameterSetName = 'Nagios')]
    param(
        [Parameter(ParameterSetName='Nagios',
            Mandatory = $false       
            )]
        [switch]  $Nagios=$true,
                
        [Parameter(ParameterSetName='Nagios',
            Mandatory = $false,
            HelpMessage = 'How old must newest updates be before Warning? (45 days)'      
            )]
        [int]  $Warning=45,
        
        [Parameter(ParameterSetName='Nagios',
            Mandatory = $false,
            HelpMessage = 'How old must newest updates be before Critical? (90 days)'      
            )]
        [int]  $Critical=90,

        [Parameter(ParameterSetName='Nagios',
            Mandatory = $false,
            HelpMessage = 'How many days must pending updates wait? (14)'      
            )]
        [int]  $MaxWaiting=14
    )
 


    #region >> Helper Functions

    function Convert-WuaResultCodeToName {
        param([Parameter(Mandatory=$True)] [int]$ResultCode)    
        $Result = $ResultCode
        switch($ResultCode) {
          1 {$Result = "Undefined"}
          2 {$Result = "Succeeded"}
          3 {$Result = "Succeeded With Errors"}
          4 {$Result = "Failed"}
          5 {$Result = "Failed"}
        }    
        return $Result
    }

    #endregion >> Helper Functions

	$ver=" (Check 1.4)"
    try {
        # Get pending updates - can return NULL
        $waitingupdates=Get-WmiObject -Namespace "root\ccm\clientsdk" -Class CCM_SoftwareUpdate
        if ($waitingupdates){$waitingupdates=1}else{$waitingupdates=0}
        
        # Get a WUA Session
        $session = (New-Object -ComObject 'Microsoft.Update.Session')
        $searcher= $session.CreateUpdateSearcher()
        $updatecount=$searcher.GetTotalHistoryCount()
        if ($updatecount -eq 0){
            $Message="Warning - No updates in Update History"
            if ($waitingupdates -gt 0){
                $Message=$Message + " - But we have updates waiting ..."
            }
            write-host "$Message  $ver"
            exit 1
        }
         
        $Datatable = New-Object System.Data.DataTable
        $r=$Datatable.Columns.Add("Date","System.Datetime")
        $r=$Datatable.Columns.Add("Result","System.String")
        $r=$Datatable.Columns.Add("KB","System.String")
        $r=$Datatable.Columns.Add("Title","System.String")
        $r=$searcher.QueryHistory(0,$updatecount)
        
        $history = $searcher.QueryHistory(0,$updatecount) |
        foreach {
            $Result = Convert-WuaResultCodeToName -ResultCode $_.ResultCode
            $Product = $_.Categories | Where-Object {$_.Type -eq 'Product'} | Select-Object -First 1 -ExpandProperty Name
            $Title=$_.Title
            if ($Title){
                $KB="KB0000000"
                if ($Title.IndexOf("(KB") -ge 0) { 
                    $KB=$Title.Substring($Title.IndexOf("(KB")+1,9)
                }
                if ($Title.IndexOf(" KB") -ge 0) { 
                    $KB=$Title.Substring($Title.IndexOf(" KB")+1,9)
                }
            
                if ($KB.IndexOf(")") -ge 1){$KB="KB0"+$KB.Substring(2,6)}
                if ($KB.IndexOf(" ") -ge 1){$KB="KB0"+$KB.Substring(2,6)}       
        
                $row = $Datatable.NewRow()
                $row.Date = $_.Date
                $row.Result = $Result
                $row.KB = $KB
                $row.Title = $Title
                $Datatable.Rows.Add($Row)
                
            }
        } 

        

        if ($Datatable.Rows.Count -eq 0){            
            $Message=" - System has no updates installed" 
            $LastUpdateDate=(Get-Date)
        }
    	
        if ($Datatable.Rows.Count -eq 1){            
            $LastUpdateDate=$Datatable.Date
            $LastUpdateKB=$Datatable.KB            
            $Message=" - Last update: " + $LastUpdateDate + " " + $LastUpdateKB        
        }
    	
        if ($Datatable.Rows.Count -gt 1){ 
            $d=$Datatable | Sort-Object -Property Date -Descending 
            $LastUpdateDate=$d[0].Date
            $k=$Datatable | Sort-Object -Property KB -Descending
            $LastUpdateKB=$k[0].KB                             
            $Message=" - Last update: " + $LastUpdateDate + " " + $LastUpdateKB        
        }

        
        if ($waitingupdates -eq 1){
            $Message=$Message + " - But we have updates waiting ..."
            $Warning=$MaxWaiting
            $Critical= 2*$Warning
        }
        if ($Warning -ge $Critical){$Critical= $Warning + 30}
        
        

        $today=(Get-Date)
        $ts=New-Timespan -Start $LastUpdateDate -End $today
        if ($ts.Days -le $warning) {
            $code = 0
            $Message1 = "OK " + $Message
        }
        if ($ts.Days -ge $warning) {
            $code=1
            $Message1="Warning " + $Message   
        }
        if ($ts.Days -ge $critical) {
            $code=2
            $Message1="Critical " + $Message
        }
        write-host "$Message1  $ver"
        exit $code
    }
    catch {
     write-host "Error: Problems in script $ver"
     exit 3
    }
