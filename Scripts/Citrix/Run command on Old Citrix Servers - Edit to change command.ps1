$credentials = Get-Credential
$computers = "BQ-CITRIX-01", "BQ-CITRIX-02", "BQ-CITRIX-05", "BQ-CITRIX-06", "BQ-CITRIX-07", "BQ-CITRIX-09", "BQ-CITRIX-10", "HQ-CITRIX-02", "HQ-CITRIX-03", "HQ-CITRIX-04", "HQ-CITRIX-05", "HQ-CITRIX-06", "HQ-CITRIX-7", "HQ-CITRIX-08", "HQ-CITRIX-10", "HQ-CITRIX-11", "HQ-CITRIX-12", "HQ-CITRIX-13", "HQ-CITRIX-14"
foreach($c in $computers){
Invoke-Command -FilePath "C:\Users\chj-dk\Desktop\AgentDeploymentScript.ps1"  -ComputerName $c -Credential $credentials
}