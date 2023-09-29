If(-not(Get-InstalledModule ImportExcel -ErrorAction silentlycontinue)){
    Install-Module ImportExcel -Confirm:$False -Force
}

If(-not(Get-InstalledModule jiraps -ErrorAction silentlycontinue)){
    Install-Module jiraps -Confirm:$False -Force
}

Set-JiraConfigServer -Server "https://jira.Base.Url"

$cred = get-credential #admin credentials e.g jira-admin

$XLSXFile = Import-Excel -path C:\Users\<user<\Downloads\Book1.xlsx 
#File containing Username, Email, login, etc. in a listed table

foreach ($x in $XLSXFile){
$disable = Get-JiraUser -UserName $x.Username -IncludeInactive -credential $cred
foreach ($d in $disable){
Set-JiraUser -User $d -Active 0 -credential $cred
}}