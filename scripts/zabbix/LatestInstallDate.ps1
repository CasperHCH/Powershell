    $session = [activator]::CreateInstance([type]::GetTypeFromProgID(“Microsoft.Update.Session”,$ComputerName))
    $us = $session.CreateUpdateSearcher()
    $qtd = $us.GetTotalHistoryCount()
    $hot = $us.QueryHistory(0, $qtd)

    # Output object
    $OutPut = @()

    #Iterating and finding updates
    foreach ($Upd in $hot) {

        # 1 means in progress and 2 means succeeded
        if ($Upd.operation -eq 1 -and $Upd.resultcode -eq 2) {
        $OutPut +=  New-Object -Type PSObject -Prop @{
                ‘ComputerName’=$computername
                ‘UpdateDate’=$Upd.date
                ‘KB’=[regex]::match($Upd.Title,’KB(\d+)’)
                ‘UpdateTitle’=$Upd.title
                ‘UpdateDescription’=$Upd.Description
                ‘SupportUrl’=$Upd.SupportUrl
                ‘UpdateId’=$Upd.UpdateIdentity.UpdateId
                ‘RevisionNumber’=$Upd.UpdateIdentity.RevisionNumber
            }
        }
    }

    #Writing updates to a text file
    $r = ($OutPut | where {$_.UpdateTitle -notlike '*Edge*'} | select -first 1).UpdateDate
    $r.ToString()