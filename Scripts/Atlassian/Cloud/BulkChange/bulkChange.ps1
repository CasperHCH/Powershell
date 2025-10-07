#requires -version 4

<#
.SYNOPSIS
	change assignee from user X to user Y
	change reporter from user X to user Y
	change request participant from user X to user Y
	change watcher from user X to user Y
	based on CSV/excel file to be determined..
.DESCRIPTION
	<Brief description of script>
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
	<Inputs if any, otherwise state None>
.OUTPUTS
	<Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         CHC
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------
Param (
 #Script parameters go here
 [String]$url,
 [String]$AdminAccount,
 [String]$token,
 [String]$List
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

#$Int is used in  the While loop as well.
#It will be increased by #1 each interation
$int = 0

#Used in While Loop, increase here if needed
#$TotalInterations will determin how many times the collection of data is repeated.
#50 results is returned pr call
$TotalInterations = 84


Import-Module ImportExcel
#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'

#Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogName = $sLogName -replace '.ps1', '.log'
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName


#Enabled Logging with timestamps, error level etc..
function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet(,,,,)]
    [String]$Level = ,

    [Parameter(Mandatory=$True)]
    [string]$Message,

    [Parameter(Mandatory=$False)]
    [string]$logfile = $sLogFile
    )

    $Stamp = (Get-Date).toString()
    $Line = 
    #If($logfile) {
        Add-Content $slogfile -Value $Line -PassThru
    #}
    #Else {
    #    Write-Output $Line
    #}
}

#Allowing for easier web requests


    $uri = $url + $uri

    try {
        If($method -eq "GET") {
            $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        }
        else{
            $response = Invoke-RestMethod -Uri $uri -Method $method -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) -Headers $headers 
        }
    } catch {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $response = $reader.ReadToEnd()
        $StatusCode = [string]$_.Exception.Response.StatusCode.value__
        $StatusDescription = [string]$_.Exception.Response.StatusDescription
        $message = $response
        $message +=   + $uri +  + $_.Exception
        Write-Log -Message $message
    }
    return $response
}
######### AddWatcherWebRequest ########
function AddWatcherWebRequest($userID, $uri){
    
    Write-Log -Message 
    Write-Log -Message 
    Write-Log -Message 
    $pair = 
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = 

    $headers = @{
     Authorization = $basicAuthValue
     'Content-Type' = 'application/json'
     'Accept' = 'application/json'
    }
    $uri = $url + $uri
    Try{
        $response = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -ContentType 'application/json' -Body $userID
        }
        catch{}
        
return $response
}


######### GetUrl #########

 
 Process{
  Try{
		$url = read-host -prompt 'provide the URL of your jira cloud site, from where you want to delete users - e.g. https://jiracloudtest.atlassian.net OBS! Remember to remove any trailing / '
		$script:url = $url.TrimEnd('/')
  }
  
  Catch{
   Write-Log -Message $_.Exception
   Break
  }
 }
 
 End{
  If($?){
   Write-Log -Message  
  }
 }
}

######### Collect Excel #########
function CollectList(){
	 'CollectList started'
	while(1){
		try{
			Write-Log -Message  
			$script:Excel = Import-Excel (read-host -prompt 'provide Excel path')
		break
		}
		Catch{
			write-host 
			Write-Log -Level ERROR -Message  
		}
	}

	Write-Log -Message  
	Write-Log -Message  ' '	
}
########## Import provided Excel #########
function ImportExcelFile(){
Begin{
  	Write-Log -Message 'ImportExcelFile started'
 }
 Process{
  Try{
   $script:Excel = Import-Excel $List
  }
  Catch{
   Write-Log -Level ERROR -Message $_.Exception
   Break
  }
 }
 End{
  If($?){
   Write-Log -Message 
  }
 }
}

######### Collect Admin account email #########

 
 Process{
  Try{
   $script:AdminAccount = read-host -prompt 'Please provide your Atlassian Admin account Email, with which you have generated a token'
	 	Write-Log -Message  
  }
  
  Catch{
   Write-Log -Level ERROR -Message $_.Exception
   Break
  }
 }
 
 End{
  If($?){
   Write-Log -Message  
  }
 }
}

######### Provide API Token#########

 
 Process{
  Try{
   $script:token = read-host -prompt 'Please insert your API Token, can be created here; https://id.atlassian.com/manage-profile/security/api-tokens'
	 	Write-Log -Message  
  }
  
  Catch{
   Write-Log -Level ERROR -Message $_.Exception
   Break
  }
 }
 
 End{
  If($?){
   Write-Log -Message 
  }
 }
}

######### Collect User Data #########

	Process {
        Write-Log -Message 'Entered; CollectUserdata - Process;'
			Try {
                Write-Log -Message 'Entered; CollectUserdata - processTry;'
                #Adding while loop, to ensure that all issues are changed for all users
                #While loop will make the script repeat 250 times, as only 50 issues per call can be returned
                #In total returning 12.500 issues.
                #If any user have more assigned/reporter/Watcher/Request Participant, repeat script, or increase 
                while ($int -ne $TotalInterations){
				    foreach($uID in $Excel){
                    Write-Log -Message 'Entered; CollectUserdata - foreach;'
                    #Collect where User is Assigned
				    	try{#Collect where User is Assigned
                             Write-Log -Message 'Entered; CollectUserdata - Try-WebApiRequest;'
                             Write-Log -Message 
                             Write-Log -Message 

				    	    $script:userAssignedList = WebApiRequest -Uri 
                              
                             Write-Log -Message 
				    		 
				    		#Use function ManipulateUserAssigneeData to change assignee to the new ID
                            #Only run it, if the returned list isnt empty
                            if ($userAssignedList.issues.key -ne $null){
				    		    ManipulateUserAssigneeData $uID.newID $userAssignedList
                              }else {Write-Log -Message }

				    	}
				    	Catch {
				    		Write-Log -Level ERROR -Message $_.Exception
				    		Break
				    	}
                           #Collect where User is Reporter
				    	try{#Collect where User is Reporter
                            Write-Log -Message 'CollectUserdata - Reporter'
				    		$Script:userReporterList = WebApiRequest -Uri 
                            Write-Log -Message 

                            #If list isnt empty, go to function ManipulateUserReporterData
                             if ($userReporterList.issues.key -ne $null){
				    		    ManipulateUserReporterData $uID.newID $userReporterList
                              }else{Write-Log -Message }
				    		
				    	}
				    	Catch {
				    		Write-Log -Level ERROR -Message $_.Exception
				    		Break
				    	}
                        #Collect where User is in Request Participant
				    	try{#Collect where User is in Request Participant
                            Write-Log -Message 'CollectUserdata - Request Participants'
                            #create useable variable.
                            $uri = '/rest/api/3/search?jql=='+$uID.old

                            $Script:userRequestParticipantList = WebApiRequest -Uri $uri


                            Write-Log -Message 
                            
                            
                            #If list isnt empty, go to function ManipulateUserRPDataAdd
				    		if ($userRequestParticipantList.issues.key -ne $null){
                                Write-Log -Message 
				    		    ManipulateUserRPDataAdd $uID.newID $userRequestParticipantList
                              }else{Write-Log -Message }
                               
                              
                            #If list isnt empty, go to function ManipulateUserRPDataDelete
                            if ($userRequestParticipantList.issues.key -ne $null){
                                 Write-Log -Message 
				    		    ManipulateUserRPDataDelete $uID.old $userRequestParticipantList
                              }else {Write-Log -Message }
				    		
				    	}
				    	Catch {
				    		Write-Log -Level ERROR -Message $_.Exception
				    		Break
				    	}
				    	try{#Collect where User is a Watcher
                             Write-Log -Message 'CollectUserdata - Watcher'
				    		$Script:userWatcherList = WebApiRequest -Uri 
                             Write-Log -Message 
                             
				    		
                            #If list isnt empty, go to function ManipulateUserWatcherDataAdd
				    		 if ($userWatcherList.issues.key -ne $null){
				    		    ManipulateUserWatcherDataAdd $uID.newID $userWatcherList
                              }else {Write-Log -Message }
				    		
                            #If list isnt empty, go to function ManipulateUserWatcherDataDelete
                            if ($userWatcherList.issues.key -ne $null){
				    		    ManipulateUserWatcherDataDelete $uID.old $userWatcherList
                              }else{Write-Log -Message }
				    		
				    	}
				    	Catch {
				    		Write-Log -Level ERROR -Message $_.Exception
				    		Break
				    	}
				    }
                #Increase the while int by 1
                $int++
				}
			}	
			Catch {
			Write-Log -Level ERROR -Message $_.Exception
			Break
			}
        }
			 
	End {
         Write-Log -Message 
		If ($?) {
		 Write-Log -Message 'Completed Successfully. Exiting CollectUserdata'
         Write-Log -Message ' '
		        }
	    }
	    
    
}

######### Manipulate User Assignee Data #########

	Process {
             Write-Log -Message 'Entered; ManipulateUserAssigneeData,Process'
			Try {

                $uIDAssigneejson = '{: }'
                Write-Log -Message 'Entered; ManipulateUserAssigneeData,try'
				foreach($Issue in $userAssignedList.issues){
					try{#Change assignee where User is $uID
                        
                        Write-Log -Message 
                        $uri = '/rest/api/3/issue/' + $Issue.key
						$assigneeUri = $uri + 
                        WebApiRequest -Uri $assigneeUri -Body $uIDAssigneejson -Method PUT | Out-Null
					}
					Catch {
						Write-Log -Level ERROR -Message $_.Exception
						Break
					    }
                    }
                 }			
			    Catch {
			    Write-Log -Level ERROR -Message $_.Exception
			    Break
			    }
		}	
		End {
            Write-Log -Message 
			If ($?) {
			Write-Log -Message 'ManipulateUserAssigneeData Completed Successfully. Exiting'
            Write-Log -Message ' '
					}
			}
}

######### Manipulate User Reporter Data #########

	Process {
        Write-Log -Message 'Entered; process'
			Try {
            Write-Log -Message 'Entered; try'
                $uIDReporterjson = '{
                    : {
                        :{:}
                }}'
                Write-Log -Message 
				foreach($Issue in $userReporterList.issues){
                 
					try{#Change assignee where User is $uID
                        $uri = '/rest/api/3/issue/' + $Issue.key
                        Write-Log -Message 
						WebApiRequest -Uri $uri -Body $uIDReporterjson -Method PUT | Out-Null
					}
					Catch {
						Write-Log -Level ERROR -Message $_.Exception
						Break
					}
                }
            }			
			Catch {
			Write-Log -Level ERROR -Message $_.Exception
			Break
			}
		}
			End {
                Write-Log -Message 
				If ($?) {
				Write-Log -Message 'ManipulateUserReporterData Completed Successfully. Exiting'
                Write-Log -Message ' '
				}
			
	        }
}

######### Manipulate User Request participant Data Add #########

	Process {
			Try {
                $uIDRequestjson = '{
                    : [ 
                                      
                                     ]
                }'
				foreach($Issue in $userRequestParticipantList.issues){
					try{#Change assignee where User is $uID
                        $uri = 
						WebApiRequest -Uri $uri -Body $uIDRequestjson -Method POST | Out-Null
					}
					Catch {
						Write-Log -Level ERROR -Message $_.Exception
						Break
					}
                }
            }			
				
			Catch {
			Write-Log -Level ERROR -Message $_.Exception
			Break
			}
			}
			End {
            Write-Log -Message 
				If ($?) {
				Write-Log -Message 'ManipulateUserRPDataAdd Completed Successfully. Exiting'
				Write-Log -Message ' '
				}
			
        }
}


######### Manipulate User Request participant Data Delete #########

	Process {
			Try {
                $uIDRequestjson = '{
                    : [ 
                                      
                                     ]
                }'
				foreach($Issue in $userRequestParticipantList.issues){
					try{#Change assignee where User is $uID
                        $uri = 
						WebApiRequest -Uri $uri -Body $uIDRequestjson -Method DELETE | Out-Null
					}
					Catch {
						Write-Log -Level ERROR -Message $_.Exception
						Break
					}
                }
            }
						
			Catch {
			Write-Log -Level ERROR -Message $_.Exception
			Break
			}
			}
			End {
            Write-Log -Message 
				If ($?) {
				Write-Log -Message 'ManipulateUserRPDataDelete Completed Successfully. Exiting'
				Write-Log -Message ' '
				}
		}
}

######### Manipulate User Watcher Data ADD #########

	Process {
        Write-Log -Message 
			Try {
                        $newWatcherID = ''
                       Write-Log -Message 
				foreach($Issue in $userWatcherList.issues){
					try{#Change assignee where User is $uID
                        $uri = 
                        Write-Log -Message 
                        
                        AddWatcherWebRequest -Uri $uri -userID $newWatcherID
						#WebApiRequest -Uri $userID -userID $newWatcherID -Method POST #| Out-Null
					}
					Catch {
						Write-Log -Level ERROR -Message $_.Exception
						Break
					}
                }
            }
				
			Catch {
			Write-Log -Level ERROR -Message $_.Exception
			Break
			}
		}
		End {
        Write-Log -Message 
			If ($?) {
			Write-Log -Message 'ManipulateUserWatcherDataAdd Completed Successfully. Exiting'
            Write-Log -Message ' '
			}
		}
}

######### Manipulate User Watcher Data DELETE #########

	Process {
			Try {
				foreach($Issue in $userWatcherList.issues){
					try{#Change assignee where User is $uID
                        Write-Log -Message 
                        $uri = 
						WebApiRequest -Uri $uri -Method DELETE | Out-Null
					}
					Catch {
						Write-Log -Level ERROR -Message $_.Exception
						Break
					}
                }
            }
					
			Catch {
			Write-Log -Level ERROR -Message $_.Exception
			Break
			}
			}
			End {
                Write-Log -Message 
				If ($?) {
                    Write-Log -Message 'ManipulateUserWatcherDataDelete Completed Successfully. Exiting'
                    Write-Log -Message ' '
				}
			}
}


#-----------------------------------------------------------[Execution]------------------------------------------------------------
#Start Log
#Start-Log -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion | Out-Null
Write-Log -Message 'Script Starting'
#----------------------------------------------------------------------------------------------------------------------------------
#Start Script Executions
#----------------------------------------------------------------------------------------------------------------------------------
#GET the URL
if($url -eq $null)
{GetUrl}
#----------------------------------------------------------------------------------------------------------------------------------
#Collect the List of users
if($List -eq $null)
{CollectList}
else {ImportExcelFile}
#----------------------------------------------------------------------------------------------------------------------------------
#Collect Admin account
if($AdminAccount -eq $null)
{CollectAdminAccount}
#----------------------------------------------------------------------------------------------------------------------------------
#Collect API Token
if($token -eq $null)
{Providetoken}
#----------------------------------------------------------------------------------------------------------------------------------
#START Execution, will do multiple things, among others;
#Collect user Data
#Manipulate user data
#Change reporter/assignee/request Paticipant/Watcher
CollectUserdata

#----------------------------------------------------------------------------------------------------------------------------------
#Stop Logging
#Stop-Log -LogPath $sLogFile

Write-Log -Message 'Script Ended'
