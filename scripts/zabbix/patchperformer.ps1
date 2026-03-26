function Get-Attributes ($arg1) {
    $searcher = New-Object system.directoryservices.directorysearcher      
    $searcher.PropertiesToLoad.Add($arg1)
    $searcher.Filter = "(&(objectClass=computer)(name=$env:ComputerName))"
    $result = $searcher.FindOne() 
    if ($result -and $result.Properties[$arg1].Count -gt 0) {
        Write-Output $result.Properties[$arg1][0]
    }
    else {
        Write-Warning "Attribute '$arg1' not found or empty."
    }
}

 $description = (Get-Attributes info)[1]
 Write-Host $description