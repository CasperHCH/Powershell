######################
# supportzip.sh
# Author: Douglas Alves - dalves@atlassian.com in behalf of Atlassian Customer Success team
# Atlassian doc:
#   https://confluence.atlassian.com/x/BZgBQw 
# Versioning:
#   0.1 20220324 - Initial version for Linux
#   0.2 20220328 - Password sanitization
#   1.0 20220419 - Linux Added thread dump
#   W1.0 202306 - Ported for Windows Power Shell
######################

param(
    [Parameter(Mandatory=$True, Position=0, ValueFromPipeline=$false)]
    [System.String]
    $a,

    [Parameter(Mandatory=$True, Position=1, ValueFromPipeline=$false)]
    [System.String]
    $h
)

$JIRAHOME=$h
$JIRAAPP=$a

$DATE=(get-date -f yyyy-MM-dd_hh-mm)

if ( !(Test-Path -Path $h) -or !(Test-Path -Path $a))
{
    echo "Usage: .\supportzip.ps1 [-h <jira home path>] [-a <jira app path>] 
          -h: obligatory, absolute path of jira home directory
          -a: obligatory, absolute path of jira application directory"
          exit 1
}

$IAM = whoami
$BEXPORT="$JIRAHOME/export"
$LOG="$BEXPORT/Jira_support.log"
$EXPORT="$BEXPORT/Jira_support_zip_$DATE"

echo ""
echo "        __          ------------------------------------------"
echo " _(\    |@@|        | Beep - Generating Atlassian Support Zip  |"
echo "(__/\__ \--/ __    /_------------------------------------------"
echo "   \___|----|  |   __"
echo "       \ }{ /\ )_ / _\"
echo "       /\__/\ \__O (__"
echo "      (--/\--)    \__/"
echo "      _)(  )(_"
echo "     `---''---`"
echo "."
echo "."
echo "##############################"
echo "# Atlassian support zip tool #"
echo "##############################"
echo "$DATE"
echo "Jira Home = $JIRAHOME"
echo "Jira App = $JIRAAPP"
echo "Current user = $IAM"
echo "."
echo "Hit CTRL+C (10s wait) if any path or user is incorrect."
sleep 10

#Create the basic structure
echo " - Creating basic structure"
echo " .... "
mkdir $EXPORT > $null
cd $EXPORT
mkdir application-properties,healthchecks,tomcat-config,application-config,auth-cfg,thread-dump,tomcat-logs,application-logs,cache-cfg,tomcat-access-logs,cluster-nodes > $null
echo " .... "

#application-logs
echo " - Packing application logs"
cp $JIRAHOME/log/* $EXPORT/application-logs/


# application-config
#Jira configuration files
echo ' - Packing application config files'
(Get-Content $JIRAHOME/dbconfig.xml) -replace '<username>.+','<username>Sanitized by Support Utility</username>' -replace '<password>.+','<password>Sanitized by Support Utility</password>' > $EXPORT/application-config/dbconfig.xml
cp $JIRAAPP/atlassian-jira/WEB-INF/classes/entityengine.xml $EXPORT/application-config/
cp $JIRAAPP/atlassian-jira/WEB-INF/classes/log4j.properties $EXPORT/application-config/
cp $JIRAAPP/bin/* $EXPORT/application-config/ 

#auth-cfg
#If exists <jira-home>/logs/support (possibly will gather old data) will grab the file however changing name to avoid confusion
echo ' - Packing configuration summary, if any available'
if(Test-Path -Path $JIRAHOME/logs/support/directoryConfigurationSummary.txt -PathType Leaf) {
    echo ' - Packing the last directoryConfigurationSummary available.'
    cp $JIRAHOME/logs/support/directoryConfigurationSummary.txt $EXPORT/auth-cfg/
}
else {
    echo ' -- Last directoryConfigurationSummary does not exist. Leaving.'
}

#tomcat-access-logs
#Get tomcat logs
echo ' - Packing all Tomcat logs'
#cp $JIRAAPP/logs/access_log* $EXPORT/tomcat-access-logs/
cp $JIRAAPP/logs/* $EXPORT/tomcat-access-logs/

#cache-cfg
echo ' - Packing cache configuration files'
cp $JIRAAPP/atlassian-jira/WEB-INF/classes/*cache.prop* $EXPORT/cache-cfg 

#tomcat-config
echo ' - Packing tomcat configuration files'
cp $JIRAAPP/conf/* $EXPORT/tomcat-config/
#sanitization
(Get-Content $EXPORT/tomcat-config/server.xml) -replace 'keystorePass=".+"','keystorePass=<sanitized_by_support>' | Set-Content $EXPORT/tomcat-config/server.xml
(Get-Content $EXPORT/tomcat-config/tomcat-users.xml) -replace 'password=".+"','password="sanitized_by_Support'  | Set-Content $EXPORT/tomcat-config/tomcat-users.xml

#healthchecks				
#If exists <jira-home>/logs/support (possibly will gather old data) will grab the file however changing name to avoid confusion
echo ' - Packing healthcheck results, if any available'
if(Test-Path -Path $JIRAHOME/logs/support/healthcheckResults.txt -PathType Leaf) {
    cp $JIRAHOME/logs/support/healthcheckResults.txt $EXPORT/healthchecks/last_healthcheckResults.txt
}
else{
    echo ' -- Last healthcheck file does not exist. Leaving without it.'
}

#application-properties
#If exists <jira-home>/logs/support (possibly will gather old data) will grab the file however changing name to avoid confusion
echo ' - Packing the application.xml, if any available'
if(Test-Path -Path $JIRAHOME/logs/support/application.xml -PathType Leaf) {
    echo " - Coppying last available application.xml"
    cp $JIRAHOME/logs/support/application.xml $EXPORT/application-properties/last-application.xml
}
else{
    echo " - No application.xml found. Leaving without it."
}


#Pack and go
echo "."; echo 'Creating zip file...'
Compress-Archive -LiteralPath $EXPORT -DestinationPath $BEXPORT/Jira_support_$DATE.zip -Force
cd $BEXPORT
echo "."
echo "."
echo "."
echo "."; echo "The support zip file can be found in $BEXPORT/Jira_support_$DATE.zip, please upload this file to Atlassian."
echo "."
echo "Have a g'day =)"
echo "."


#EOF
