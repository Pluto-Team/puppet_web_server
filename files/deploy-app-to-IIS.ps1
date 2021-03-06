   # bring down a specific version of the application and deploy it to IIS
#Install-Module -Nam AWS.Tools.Common -Force -Verbose
# Install-Module -Name AWS.Tools.EC2 -Force -Verbose

$websiteConfig = ""
Set-Alias "appcmd" C:\Windows\System32\inetsrv\appcmd.exe

Write-Host "##### Finding Web application package #####"
$instanceId = ( Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/instance-id )

Write-Host "Instance ID -->" $instanceId

Write-Host "#### Retrieving the server console name tag ####"
$webServerConsoleNameTag = ( aws ec2 describe-tags --filters "Name=resource-id,Values=$instanceId" | jq -r '.Tags[0].Value' )

Write-Host "The server console name tag is " $webServerConsoleNameTag

Write-Host "#### Bringing Down the application ####"
if( $webServerConsoleNameTag -eq "Candidate-tracker-Dev-Web-Server" ) {

    $websiteConfig = "candidate-tracker-site-dev.xml"
    Write-Host "Bringing down Dev Branch of Candidate tracker"
    aws s3 cp s3://pluto-app-artifact-store/Dev/PlutoApp-Dev/ C:\inetpub\wwwroot\CandidateTracker\ --recursive

    Write-Host "#### PULLING DOWN WEB.CONFIG #####"
    aws s3 cp s3://server-standup-files-pluto-app/web-server/web.config C:\inetpub\wwwroot\CandidateTracker\

    Write-Host "#### ADDING IN WEBSITE AND APP POOL CONFIGURATION TO IIS SITE FOR DEV BUILD"
    aws s3 cp s3://server-standup-files-pluto-app/web-server/$websiteConfig C:\file-drop\$websiteConfig
    aws s3 cp s3://server-standup-files-pluto-app/web-server/candidate-tracker-app-pool.xml C:\file-drop\candidate-tracker-app-pool.xml
   
   # deploy the application to IIS with the correct web config
}

else {
  $websiteConfig = "candidate-tracker-site-test.xml"
  Write-Host "Bringing down Test Branch of Candidate tracker"
  # bring down the most current version from the Test folder
  aws s3 cp s3://pluto-app-artifact-store/Test/PlutoApp-Test/ C:\inetpub\wwwroot\CandidateTracker\ --recursive

  Write-Host "#### PULLING DOWN WEB.CONFIG #####"
  aws s3 cp s3://server-standup-files-pluto-app/web-server/web.config C:\inetpub\wwwroot\CandidateTracker\

  Write-Host "#### ADDING IN WEBSITE AND APP POOL CONFIGURATION TO IIS SITE FOR TEST BUILD"
  aws s3 cp s3://server-standup-files-pluto-app/web-server/$websiteConfig C:\file-drop\$websiteConfig
  aws s3 cp s3://server-standup-files-pluto-app/web-server/candidate-tracker-app-pool.xml C:\file-drop\candidate-tracker-app-pool.xml
}

# workaround to pass powershell variables into command line commands
$env:siteConfig = $websiteConfig

Write-Host "#### IMPORTING IIS SITE CONFIG TO IIS "
cmd /c --% C:\Windows\System32\inetsrv\appcmd.exe add apppool /in < C:\file-drop\candidate-tracker-app-pool.xml
cmd /c --% C:\Windows\System32\inetsrv\appcmd.exe add site /in < C:\file-drop\%siteConfig% 
