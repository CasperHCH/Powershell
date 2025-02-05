Get-ADComputer -Filter * -SearchBase  -Properties ms-Mcs-Admpwd | sort name | ft name, ms-Mcs-Admpwd -AutoSize
