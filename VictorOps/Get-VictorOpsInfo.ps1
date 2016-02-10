<#   
.SYNOPSIS   
   This script utilizes the VictorOps API to return requested information.
.DESCRIPTION 
   This script can be used in various ways. This implementation returns data and interacts with the API to ack alerts. 
   It can also return values which can be used by PRTG sensors.
   
   Variable structure:
    $apiKey       = Your Victor OPs API Key   
    $apiID        = Your Victor OPs API ID
    $baseURL      = The base URL for the VictorOPs API. You shouldn't need to change this. 
    $acceptheader = "application/json" - this default should be fine
    
    The below information is gathered using the above variables.
    
    $headers = @{ 
    'Accept'       = $acceptheader
    'X-VO-Api-Id'  = $apiID
    'X-VO-Api-Key' = $apiKey    
    }
    
    For more info on the VictorOps API, visit https://portal.victorops.com/public/api-docs.html#/.
.PARAMETER getInfo
    Specify the information you'd like returned or action to take.
    
    ack       = List/ack any outstanding alerts
    OnCall    = List who is currently on call (must specify team with -team parameter) (compatible with -format parameter and PRTG sensors)
    UserSched = Get a user's oncall schedule. Best to return this into your own variable for now. (Must specify -user parameter)
    Upcoming  = See who is on call for a team in the future. (must specify team with -team parameter)
    Incident  = List all incidents (compatible with -format parameter and PRTG sensors)
 
.PARAMETER team
    Specify the name of the team. If you have not setup the switch information later in this script, do so to ensure it lines up.
    
.PARAMETER user
    Specify the username you're getting info for.

.PARAMETER format
    Specify 'prtg' for certain -getInfo parameters and it will dump it as PRTG sensor information.
    
.NOTES   
    Name: Get-VictorOpsInfo.ps1
    Author: Ginger Ninja (Mike Roberts)
    DateCreated: 1/28/16
.LINK  
    http://www.gngrninja.com/script-ninja/2016/1/28/powershell-using-the-victorops-rest-api     
.EXAMPLE   
    .\Get-VictorOpsInfo.ps1 -getInfo OnCall -team unix
 .Example
    .\Get-VictorOpsInfo.ps1 -getInfo ack
#> 
[cmdletbinding()]
param(
    [string]
    $team,
    [string]
    $getInfo = 'notset',
    [string]
    $user,
    [string]
    $format = 'user'
)

if (!((Get-PSSnapin -name "Quest.ActiveRoles.ADManagement" -ea SilentlyContinue).name -eq "Quest.ActiveRoles.ADManagement")) {
  
        Write-Host `n"Loading Quest Active Directory Tools Snapin..."`n -ForegroundColor $foregroundColor
     
        Add-PSSnapin Quest.ActiveRoles.ADManagement | Out-Null
    }  if(!$?) {

        Write-Host `n"You need to install Quest Active Directory Tools Snapin from http://software.dell.com/products/activeroles-server/powershell.aspx"`n -ForegroundColor Red

        Start-Process "http://software.dell.com/products/activeroles-server/powershell.aspx"
        Break;
}

$apiKey       = ''
$apiID        = ''
$baseURL      = 'https://api.victorops.com' 
$acceptheader = "application/json"

$headers = @{
    'Accept'       = $acceptheader
    'X-VO-Api-Id'  = $apiID
    'X-VO-Api-Key' = $apiKey
}

function Get-OnCallSchedule {
    [cmdletbinding()]
    param(
        [string]
        $baseURL,
        [string]
        $onCallURL
    )
    

    $fullURL = $baseURL + $onCallURL
    
    if ($fullURL) {
        
        $onCallSchedule = Invoke-RestMethod $fullURL -Headers $headers
        
    }
    
    return $onCallSchedule
    
}

function Get-Incident {
    [cmdletbinding()]
    param($baseURL)
    
    $incidentURL     = '/api-public/v1/incidents'
    $fullURL         = $baseURL + $incidentURL
    $onCallIncidents = (Invoke-RestMethod $fullURL -Headers $headers).Incidents

    Return $onCallIncidents
    
}

function Resolve-Incident {
    [cmdletbinding()]
    param ($baseURL)

    $incidents = Get-Incident $baseURL
    
    $i = 0
    
    foreach ($in in $incidents) {
        
        if ($in.currentPhase -like 'UNACKED') {
            
            $i++
            
            $ackURL  = "/api-public/v1/incidents/ack"
            
            $fullURL = $baseURL + $ackURL
            
            Write-Host $in.EntityDisplayName
            Write-Host $in.incidentNumber
            
            $inName = $in.EntityDisplayName
            $inNum  = $in.incidentNumber
            
            Write-Host $fullURL
            
            if ((Read-Host "Ack this alert?") -like "*y*") {       
    
                $ackUser = (Get-ChildItem ENV:\USERNAME).Value  
                $ackMsg  = Read-Host "Ack message?"    
                $outputString = $null
                $outputString = "{
                `"userName`": `"$ackUser`",
                `"incidentNames`": [
                `"$inNum`"
                ],
                `"message`": `"$ackMsg`"
                }"

                Invoke-RestMethod -URi $fullURL -Method Patch -contentType "application/json" -Headers $headers -body $outputString
            
            }
           
            } elseif ($in.currentPhase -like 'ACKED') {
                
                $i++
                
                $ackURL  = "/api-public/v1/incidents/resolve"
                
                $fullURL = $baseURL + $ackURL
                
                Write-Host $in.EntityDisplayName
                Write-Host $in.incidentNumber
                
                $inName = $in.EntityDisplayName
                $inNum  = $in.incidentNumber
                
                if ((Read-Host "Resolve this alert?") -like "*y*") {       
        
                    $ackUser = (Get-ChildItem ENV:\USERNAME).Value  
                    $ackMsg  = Read-Host "Resolution message?"    
                    $outputString = $null
                    $outputString = "{
                    `"userName`": `"$ackUser`",
                    `"incidentNames`": [
                    `"$inNum`"
                    ],
                    `"message`": `"$ackMsg`"
                    }"

                    Invoke-RestMethod -URi $fullURL -Method Patch -contentType "application/json" -Headers $headers -body $outputString
                 
                } 
           }   
    }
    
    if ($i -eq 0) { Write-Host "No alerts to ack or resolve!" }
    
}


Switch ($team) {
  
    {$team -like "*team1*"}  {
        
        $teamName ='team1name'
    
    }

    {$team -like "*team2*"} {
        
        $teamName = 'team2name'
    
    }  
    
}

Switch ($getInfo) {
    
    {$_ -like "OnCall"} {
       
        if (!$team) {Write-Host `n"Team not specified!"`n -foregroundcolor Red;break}
        
        $onCallURL      = "/api-public/v1/team/$teamName/oncall/schedule"
        $onCallSchedule = Get-OnCallSchedule $baseurl $oncallurl  
        $onCallUser     = Get-QADuser $onCallSchedule.Schedule.onCall
        
        if ($onCallUser) {
           
            $name   = $onCallUser.Name
            $mobile =  $onCalluser.MobilePhone
        
            Switch ($format) {
         
                {$_ -eq 'user'} {
                 
                    Write-Host `n"Currently on call for team: $team"
                    Write-Host $name "($mobile)"`n
                 
                }
             
                {$_ -eq 'prtg'} {
             
                    Write-Host "<prtg>"                     
                    Write-Host
                    "<result>"
                    "<channel>Team: $team</channel>"
                    "<value>1</value>"
                    "</result>" 
                    "<text>$name ($mobile)</text>"
                    Write-Host "</prtg>"
                    
                }
           
             }
         
         }
    }  
  
  {$_ -like "*Upcoming*"} {

        if (!$team) {Write-Host `n"Team not specified!"`n -foregroundcolor Red;break}
        
        $onCallURL      = "/api-public/v1/team/$teamName/oncall/schedule"
        $onCallSchedule = Get-OnCallSchedule $baseurl $oncallurl  
        $upcoming       = $onCallSchedule.schedule.rolls
        
        $upcoming | ForEach-Object{$WeekOf = $_.change.SubString(0,10);$Who = (Get-QADUser $_.OnCall).Name; Write-Host $WeekOf $Who}
          
  } 
  
  {$_ -like "*incidents*"} {
      
        $incidents = Get-Incident $baseURL
        
        $unAcked   = $incidents | Where-Object{$_.currentPhase -eq 'UNACKED'}
        $unRes     = $incidents | Where-Object{$_.currentPhase -eq 'ACKED'}
        $resAlerts = $incidents | Where-Object{$_.currentPhase -eq 'RESOLVED'}
        
        if ($unAcked) {
            
            $counta = 1
            if ($unAcked.Count) {$counta = $unAcked.Count}
            $texta    = $unAcked.entityDisplayName 
          
        } else {$counta = 0;$texta = "No alarms in VictorOps!" }
        
        if ($unRes) {
            
            $countr = 1
            if ($unRes.Count) {$countr = $unRes.Count}
            $textr    = $unRes.entityDisplayName 
          
        } else {$countr = 0}  
              
        if ($resAlerts) {
       
            $countre = 1
            if ($resAlerts.Count) {$countre = $resAlerts.Count} 
          
        } else {$countre = 0}          
        
        Switch ($format) {
            
            {$_ -eq 'prtg'} {
                
                Write-Host "<prtg>"    
                                 
                Write-Host
                "<result>"
                "<channel>Unacknowledged Alerts</channel>"
                "<value>$counta</value>"
                "</result>" 
                "<text>$texta</text>"
            
                Write-Host
                "<result>"
                "<channel>Unresolved Alerts</channel>"
                "<value>$countr</value>"
                "</result>" 
                "<text>$textr</text>"
        
                Write-Host
                "<result>"
                "<channel>Resolved Alerts</channel>"
                "<value>$countre</value>"
                "</result>" 
                "<text>$textre</text>"
                
                Write-Host "</prtg>"        
                     
            }
            
            {$_ -eq 'user'} {
                
                Write-Host `n"Unacknowledged Alerts" 
                Write-Host `t$counta `n -foregroundcolor Red
                
                Write-Host "List:"`n
                
                foreach ($alert in $unAcked) {
                
                   Write-Host `t $alert.entityDisplayName `n
                
                }                
                
                Write-Host "Unresolved Alerts" 
                Write-Host `t$countr `n -foregroundcolor Red

                Write-Host "List:"`n
                
                foreach ($alert in $unRes) {
                
                   Write-Host `t $alert.entityDisplayName `n
                
                }

                
                Write-Host "Resolved Alerts" 
                Write-Host `t$countre`n -foregroundcolor Green
                
                Write-Host "List:"`n
                
                foreach ($alert in $resAlerts) {
                
                   Write-Host `t $alert.entityDisplayName `n
                
                }
            }
        }

        
  }
  
  {$_ -like "*usersched*"} {
      
        if ($user) {
      
            $onCallURL      = "/api-public/v1/user/$user/oncall/schedule"
            $onCallSchedule = Get-OnCallSchedule $baseurl $oncallurl
            Return $onCallSchedule

        } else {Write-Host `n"User not specified!"`n -foregroundcolor Red}
  }
  
  {$_ -like "ack"} {
      
      Resolve-Incident $baseURL
      
  }
   
  {$_ -eq 'notset'} {
      
      Write-Host `n"Please specify the action you'd like to take via the -getInfo parameter" -foregroundColor Red
      Write-Host "For help type Get-Help .\scriptName.ps1"`n
      
  } 
                    
}   