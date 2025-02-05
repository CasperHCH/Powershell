function Start-ADSync {
    [CmdletBinding()]
    Param (
        [Switch]$delta,
        [Switch]$full
    )

    process {
        if ($delta) {
            try {
                Invoke-Command -ComputerName prod-adsync-01 -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta }
            }

            catch {
		        Write-Warning $_.Exception.Message
    		    Break
    	    }
        }
     
        if ($full) {
            try {
                Invoke-Command -ComputerName prod-adsync-01 -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Initial }
            }

            catch {
            	Write-Warning $_.Exception.Message
	           	Break
            }
	    }

        if (!($delta -or $full)) {
            Write-Warning 
        }
    }
}
