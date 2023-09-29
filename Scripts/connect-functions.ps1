### EXCHANGE ###

# Functions to connect / disconnect Remote Exchange Management Shell
Function Connect-ExchPowershell {
    $RPSession = New-PSSession -Name "ExchSession" -ConfigurationName Microsoft.Exchange -ConnectionURI http://BQ-MBX-02/Powershell
    Import-PSSession $RPSession -Prefix local
} #end function

Function Disconnect-ExchPowershell {
    Get-PSSession -Name "ExchSession" | Remove-PSSession
} #end function

### END EXCHANGE ###


###  O365  ###

# Functions to connect / disconnect remote Exchange Management Shell on O365
Function Connect-O365Powershell {
    $O365Session = New-PSSession -Name "O365Session" -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential (Get-Credential) -Authentication Basic -AllowRedirection
    Import-PSSession $O365Session -DisableNameChecking -Prefix cloud
}

Function Remove-O365Powerhell {
    Get-PSSession -Name "O365Session" | Remove-PSSession
}

###  END O365  ###


### LYNC ###

# Functions to connect / disconnect remote Lync Management Shell
Function Connect-LyncPowershell {
    $CSSession = New-PSSession -Name "CSSession" -ConnectionUri "https://LyncAdmin.eetgroup.com/OcsPowershell" -Credential (Get-Credential)
    Import-PSSession $CSSession
} #end function

Function Disconnect-LyncPowershell {
    Get-PSSession -Name "CSSession" | Remove-PSSession
} #end function

## END LYNC