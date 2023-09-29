##Add calendar meeting - to remind admin to run the script again
function Add-CalendarMeeting {

param (

[cmdletBinding()]

	# Subject Parameter	
    [Alias('sub')]
    [string] $Subject = "You've set this account to Expire today: $DisableUserName",

	#Body parameter
    [Alias('bod')]
    [string] $Body = "Please run the Offboarding script again, to ensure a full disable and cleanup of the user: $DisableUserName",

	#Location Parameter
    [Alias('loc')]
    [string] $Location = "Local Desktop",

	# Importance Parameter
	[int] $Importance = 1,

	# All Day event Parameter
	[bool] $AllDayEvent = $false,

	# Set Reminder Parameter
	[bool] $EnableReminder = $True,

	# Busy Status Parameter
	[string] $BusyStatus = 2,

	# Metting Start Time Parameter
	[datetime] $MeetingStart = $DisableUserOnDate,

	# Meeting time duration parameter
	[int] $MeetingDuration = 30, 

	# Meeting time End parameter
		#[datetime] $MeetingEnd = (Get-Date).AddMinutes(+30),

	# by Default Reminder Duration
	[int] $Reminder = 15



)

BEGIN { 
        
        Write-Verbose " Creating Outlook as an Object"
        
        # Create a new appointments using Powershell
        $outlookApplication = New-Object -ComObject 'Outlook.Application'
        # Creating a instatance of Calenders
        $newCalenderItem = $outlookApplication.CreateItem('olAppointmentItem')



      }


PROCESS { 
        
         Write-Verbose "Creating Calender Invite"
    
         $newCalenderItem.AllDayEvent = $AllDayEvent
         $newCalenderItem.Subject = $Subject
         $newCalenderItem.Body = $Body
         $newCalenderItem.Location  = $Location
         $newCalenderItem.ReminderSet = $EnableReminder
         $newCalenderItem.Importance = $importance


         if ( ! ($AllDayEvent)) {

         $newCalenderItem.Start = $MeetingStart
         $newCalenderItem.Duration = $MeetingDuration
         
         }
         
         $newCalenderItem.ReminderMinutesBeforeStart = $Reminder
         # 2 is busy, 3 is ou to office
         $newCalenderItem.BusyStatus = $BusyStatus
             
    }

END {
    
        Write-Verbose "Saving Calender Item"
        $newCalenderItem.Save()
      
        # if you want to see the calener invite un-comment the below line
            #un-comment it ==>  $newCalenderItem.Display($True)

       }

	}