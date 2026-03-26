[Int]$waitingupdates = 0

if ((Get-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate).WUServer -like "*scm*") {
      # Get pending updates - can return NULL
      
      $waitingupdates = @(Get-WmiObject -Namespace "root\ccm\clientsdk" -Class CCM_SoftwareUpdate -Filter "NOT Name like '%Edge%'").Count
      if ($waitingupdates -gt 0){$waitingupdates}else{[Int]$waitingupdates}
      
      }
      else {
      # Get a WUA Session
        [Int]$waitingupdates = 0
        $Searcher = new-object -com "Microsoft.Update.Searcher"
        $Searcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0").Updates | Where-Object -FilterScript {$_.Title -notlike '*Edge*'} | ForEach-Object { $waitingupdates++ }
        Write-Host $waitingupdates
        }