### EXCHANGE ###

# Functions to connect / disconnect Remote Exchange Management Shell
Function Connect-ExchPowershell {
    $RPSession = New-PSSession -Name "ExchangeRemoting" -ConfigurationName Microsoft.Exchange -ConnectionURI http://BQ-MBX-02/Powershell
    Import-PSSession $RPSession -Prefix local
    Write-Host "Connected to Exchange Server" -ForegroundColor Green
} #end function

Function Disconnect-ExchPowershell {
    Get-PSSession -Name "ExchangeRemoting" | Remove-PSSession
    Write-Host "Disconnected from Exchange Server" -ForegroundColor Yellow
} #end function

### END EXCHANGE ###


###  O365  ###

# Functions to connect / disconnect remote Exchange Management Shell on O365
Function Connect-O365Powershell {
    $O365Session = New-PSSession -Name "O365Remoting" -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential (Get-Credential) -Authentication Basic -AllowRedirection
    Import-PSSession $O365Session -DisableNameChecking -Prefix cloud
    Write-Host "Connected to Office 365" -ForegroundColor Green
}

Function Remove-O365Powershell {
    Get-PSSession -Name "O365Remoting" | Remove-PSSession
    Write-Host "Disconnected from Office 365" -ForegroundColor Yellow
}

###  END O365  ###


### LYNC ###

# Functions to connect / disconnect remote Lync Management Shell
Function Connect-LyncPowershell {
    $CSSession = New-PSSession -Name  -ConnectionUri  -Credential (Get-Credential)
    Import-PSSession $CSSession
} #end function

Function Disconnect-LyncPowershell {
    Get-PSSession -Name  | Remove-PSSession
} #end function

## END LYNC
