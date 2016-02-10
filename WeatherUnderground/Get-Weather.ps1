[cmdletbinding()]
param(
    [string]
    $city = (Read-Host "City?"),
    [string]
    $forecast = 'forecast',
    [boolean]
    $sendEmail,
    [boolean]
    $lifx,
    [boolean]
    $sendAlertEmail
)

if (!$foregroundColor) {$foregroundColor = 'green'}
$baseURL      = 'http://api.wunderground.com/api/'
$apiKey       = ''
$acceptHeader = 'application/json'

#"password" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File .\emlpassword.txt

$emailPass    = Get-Content .\emlpassword.txt | ConvertTo-SecureString  
$weatherList  = Get-Content .\emails.txt
$alertList    = Get-Content .\alertEmails.txt
$emailUser    = 'emluser'
$emailFrom    = 'emailFrom'
$smtpServer   = 'smtp.gmail.com'
$smtpPort     = '587'

function Get-Weather {
    param()
   
    $findMe = $city
    $find   = Invoke-RestMethod -Uri "http://autocomplete.wunderground.com/aq?query=$findMe"

    if ($find) {
        
        $cityAPI  = $find.Results[0].l
        $city     = $find.Results[0].name
        
        $fullURL  = $baseURL + $apiKey + "/features/conditions/hourly/forecast/webcams/alerts" + "$cityAPI.json"
        $radarURL = "http://api.wunderground.com/api/$apiKey/animatedradar/animatedsatellite" + "$cityAPI.gif?num=6&delay=50&interval=30"
        
        Write-Host `n"API URLS for $city" -foregroundcolor $foregroundColor
        Write-Host `t$fullURL
        Write-Host `t$radarURL
        
        $weatherForecast = Invoke-RestMethod -Uri $fullURL -ContentType $acceptHeader
        
        $currentCond     = $weatherForecast.current_observation
        
        Write-Host `n"Current Conditions for: $city" -foregroundColor $foregroundColor
        Write-Host $currentCond.Weather 
        Write-Host "Temperature:" $currentCond.temp_f"F"
        Write-Host "Winds:" $currentCond.wind_string
        
        $curAlerts = $weatherForecast.alerts 
        
        if ($curAlerts) {
            
            if ($lifx) { Get-LIFXAPI -action flashcolor -brightness 1 -color Red -state on }
            
            $typeName = Get-WeatherFunction -Weather 'alert' -value $weatherForecast.alerts
            
            $alertDate  = $curAlerts.date
            $alertExp   = $curAlerts.expires 
            $alertMsg   = $curAlerts.message
            
            Write-Host `n"Weather Alert! ($typeName)" -foregroundcolor Red
            Write-Host "Date: $alertDate Expires: $alertExp"
            Write-Host "$alertMsg"    
            
            if ($sendAlertEmail) {

                Foreach ($email in $alertList) {
                    
                    Send-WeatherEmail -to $email -Subject "Weather Alert!" -Body "Alert Type: $typeName City: $city Message: $alertMsg"
                
                }
            }                  

        } 
        
    }

    Switch ($forecast) {
    
        {$_ -eq 'hourly'} {
 
            if ($sendEmail) {

                $hourlyForecast = $weatherForecast.hourly_forecast
                
                $body = "<p></p>"
                $body += "<p>Here is your hourly forecast!</p>"
                
                $selCam   = Get-Random $weatherForecast.webcams.count
                
                $camImg   = $weatherforecast.webcams[$selCam].CURRENTIMAGEURL
                $camName  = $weatherForecast.webcams[$selCam].linktext
                $camLink  = $weatherForecast.webcams[$selCam].link
                
                $body += "<p>Random webcam shot from: <a href=`"$camLink`">$camName</a></p>"
                $body += "<p><img src=`"$camImg`"></p>"                 
                                
                $body += "<p>$city Radar:</p>"
                $body += "<p><img src=`"$radarURL`"></p>"  
                
                if ($curAlerts) {
                    
                    $body += "<p><b><font color=`"red`">Weather Alert! ($typeName)</font></b></p>"
                    $body += "<p>Date: $alertDate Expires: $alertExp</p>"
                    $body += "<p>$alertMsg</p>"    
    
                }           
                
                foreach ($hour in $hourlyForecast) {
                    
                    $body += "<p></p>"
                    $body += "<p></p>"
                    
                    $prettyTime       = $hour.fcttime.pretty
                    $hourTemp         = $hour.temp.english  
                    $hourImg          = $hour.icon_url
                    
                    [int]$hourChill   = $hour.windchill.english
                    
                    if ($hourChill -eq -9999) {
                    
                        $hourChilltxt = 'N/A'
                        
                    } else {
                        
                        $hourChilltxt = $hourChill.ToString() + 'F'
                   
                    }
                                        
                    $hourWind         = $hour.wspd.english
                    $windDir          = $hour.wdir.dir
                    $hourUV           = $hour.uvi
                    $dewPoint         = $hour.dewpoint.english
                    $hourFeels        = $hour.feelslike.english
                    $hourHum          = $hour.humidity
                    $conditions       = $hour.condition
                    [int]$hourPrecip  = $hour.pop
                    
                    $popText = Get-WeatherFunction -Weather 'preciptext' -value $hourPrecip
                    
                    $body += "<p><b>$prettyTime</b></p>"
                    $body += "<p><img src=`"$hourImg`">$conditions</p>"
                    $body += "<p>Chance of precipitation: $hourPrecip% / $popText</p>"
                    $body += "<p>Current Temp: $hourTemp`F Wind Chill: $hourChilltxt Feels Like: $hourFeels`F</p>"
                    $body += "<p>Dew Point: $dewPoint</p>"
                    $body += "<p>Wind Speed: $hourWind`mph Direction: $windDir</p>"
                    $body += "<p>Humidity: $hourHum%</p>"
                    $body += "<p>UV Index: $hourUV"     
                    
                }
                
                foreach ($email in $weatherList) {Send-WeatherEmail -To $email -Subject "Your hourly forecast for $city" -body $body}
            
            }            
        
        }
        
        {$_ -eq 'forecast'} {                
              
            if ($sendEmail) {

                $todayForecast = $weatherForecast.forecast.simpleforecast.forecastday
                
                $body = "<p></p>"
                $body += "<p>Here is your 4 day forecast!</p>"
                
                $selCam   = Get-Random $weatherForecast.webcams.count
                
                $camImg   = $weatherforecast.webcams[$selCam].CURRENTIMAGEURL
                $camName  = $weatherForecast.webcams[$selCam].linktext
                $camLink  = $weatherForecast.webcams[$selCam].link
                
                $body += "<p>Random webcam shot from: <a href=`"$camLink`">$camName</a></p>"
                $body += "<p><img src=`"$camImg`"></p>"                 
                
                $body += "<p>$city Radar:</p>"
                $body += "<p><img src=`"$radarURL`"></p>"      
                
                $curAlerts = $weatherForecast.alerts 
                
                if ($curAlerts) {
                    
                    $body += "<p><b><font color=`"red`">Weather Alert! ($typeName)</font></b></p>"
                    $body += "<p>Date: $alertDate Expires: $alertExp</p>"
                    $body += "<p>$alertMsg</p>"    

                }                   
               
                foreach ($day in $todayForecast) {
                    
                    $body += "<p></p>"
                    $body += "<p></p>"
                    
                    $dayImg          = $day.icon_url
                    $dayMonth        = $day.date.monthname
                    $dayDay          = $day.date.day
                    $dayName         = $day.date.weekday
                    $dayHigh         = $day.high.fahrenheit  
                    $dayLow          = $day.low.fahrenheit
                    $maxWind         = $day.maxwind.mph
                    $aveWind         = $day.avewind.mph
                    $aveHum          = $day.avehumidity
                    $conditions      = $day.conditions
                    [int]$dayPrecip  = $day.pop
                    
                    $popText = Get-WeatherFunction -Weather 'preciptext' -value $dayPrecip
                    
                    $body += "<p><b>$dayName, $dayMonth $dayDay</b></p>"
                    $body += "<p><img src=`"$dayImg`">$conditions</p>"
                    $body += "<p>Chance of precipitation: $dayPrecip% / $popText</p>"
                    $body += "<p>High: $dayHigh`F Low: $dayLow`F</p>"
                    $body += "<p>Ave Winds: $aveWind`mph Max Winds: $maxWind`mph</p>"
                    $body += "<p>Humidity: $aveHum%</p>"
         
                }

                foreach ($email in $weatherList) {Send-WeatherEmail -To $email -Subject "Your 4 day forecast for $city" -body $body}
            
            }  
            
        }

        {$_ -eq 'camera'} {
            
            $selCam    = Get-Random $weatherForecast.webcams.count
            
            $camImg    = $weatherforecast.webcams[$selCam].CURRENTIMAGEURL
            $camName   = $weatherForecast.webcams[$selCam].linktext
            $camLink   = $weatherForecast.webcams[$selCam].link
            
            $fileExt   = $camImg.SubString($camImg.LastIndexOf("."),4)
            
            $cityShort = $city.substring(0,$city.lastindexof(","))
            
            $fileName  = $cityShort + $fileExt
            
            $location  = (Get-Location).Path
            
            $camFile   = Invoke-WebRequest -Uri $camImg -OutFile "$location\$fileName"   
            
            $file = $location + "\" + $fileName
            
            $gallery = 'YourSquareSpaceGalleryOrEmailToSendAttachmentTo' 
            
            $SMTPClient             = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
            $SMTPMessage            = New-Object System.Net.Mail.MailMessage($emailFrom,$gallery,"$city cam","$city cam")
            $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($emailUser,$emailPass)
            
            $att                    = New-Object Net.Mail.Attachment($file)
            $SMTPClient.EnableSsl   = $true
           
            Switch (($fileName.substring($fileName.LastIndexOf(".")+1)).tolower()) {
                
                {$_ -like "*png*"} {
                
                    $typeExt = 'png'    
                    
                }
                
                {$_ -like "*jpg*"} {
                
                    $typeExt = 'jpg'     
                    
                }
                
                {$_ -like "*gif*"} {
                    
                    $typeExt = 'gif' 
                    
                }                                
                
            }
            
            $SMTPMessage.Attachments.Add($att)
            ($smtpmessage.Attachments).contenttype.mediatype = "image/$typeExt"
            
            $SMTPClient.Send($SMTPMessage)
            
            $att.Dispose()
            $SMTPMessage.Dispose()
            
            Remove-Item $file
            
        }
    
    } 
    
    Return $weatherForecast

}

function Send-WeatherEmail {
    [cmdletbinding()]
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]
    $To,
    
    [string]
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    $Subject,
    
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    $Body,
    
    [string]
    $attachment
    )

    if (!$to)      {Write-Error "No recipient specified";break}
    if (!$subject) {Write-Error "No subject specified";break}
    if (!$body)    {Write-Error "No body specified";break}
   
    $gmailCredential = New-Object System.Management.Automation.PSCredential($emailUser,$emailPass)
       
    Send-MailMessage -To $to -From $emailFrom -Body $body -BodyAsHtml:$true -Subject $Subject -SmtpServer $smtpServer -Port $smtpPort -UseSsl -Credential $gmailCredential
 
}

function Get-WeatherFunction {
    [cmdletbinding()]
    param(
        [string]
        $weather,
        $value       
    )
    
    Switch ($weather) {
        
        {$_ -eq 'preciptext'} {
        
            Switch ($value) {
                
                {$_ -lt 20} {
                    
                    $popText = 'No mention'
                    
                }
                
                {$_ -eq 20} {
                    
                    $popText = 'Slight Chance'
                    
                }
                
                {($_ -lt 50 -and $_ -gt 20)} {
                    
                    $popText = 'Chance'
                    
                }
                
                {$_ -eq 50} {
                    
                    $popText = 'Good chance'
                    
                }
                
                {($_ -lt 70 -and $_ -gt 50)} {
                    
                    $popText = 'Likely'
                    
                }
                
                {$_ -ge 70} {
                    
                    $popText = 'Extremely likely'
                    
                }
                
            }
            
            Return $popText
            
        }   
        
        {$_ -eq 'alert'}    {
            
            Switch ($curAlerts.type) {
                
                'HEA' {$typeName = 'Heat Advisory'}
                'TOR' {$typeName = 'Tornado Warning'}
                'TOW' {$typeName = 'Tornado Watch'}
                'WRN' {$typeName = 'Severe Thunderstorm Warning'}
                'SEW' {$typeName = 'Severe Thunderstorm Watch'}
                'WIN' {$typeName = 'Winter Weather Advisory'}
                'FLO' {$typeName = 'Flood Warning'}
                'WAT' {$typeName = 'Flood Watch / Statement'}
                'WND' {$typeName = 'High Wind Advisory'}
                'SVR' {$typeName = 'Severe Weather Statement'}
                'HEA' {$typeName = 'Heat Advisory'}
                'FOG' {$typeName = 'Dense Fog Advisory'}
                'SPE' {$typeName = 'Special Weather Statement'}
                'FIR' {$typeName = 'Fire Weather Advisory'}
                'VOL' {$typeName = 'Volcanic Activity Statement'}
                'HWW' {$typeName = 'High Wind Warning'}
                'REC' {$typeName = 'Record Set'}
                'REP' {$typeName = 'Public Reports'}
                'PUB' {$typeName = 'Public Information Statement'}
                    
            }
                
            Return $typeName
    
        }    
    }
    
}

function Get-LIFXApi {
[cmdletbinding()]
param(
    [string]
    $action = 'setstate',
    [string]
    $state = 'on',
    [string]
    $color = 'white',
    [double]
    $brightness = '0.4'
)

$apiKey          = ''
$base64Key       =  [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(($apiKey)))
$headers         =  @{Authorization=("Basic {0}" -f $base64Key)}
$allURL          = 'https://api.lifx.com/v1/lights/all' 
$acceptheader    = 'application/json'
$baseURL         = 'https://api.lifx.com/v1/lights/'
$foregroundColor = 'white'
[array]$colors   = @('white','red','orange','yellow','cyan','green','blue','purple','pink')

$ninjaLights     = Invoke-RestMethod -headers $headers -Uri $allURL

function Change-LightState {
    [cmdletbinding()]
    param(
        [string]
        $state,
        [string]
        $color,
        [double]
        $brightness,
        [string]
        $selector
    )
    
    $ninjaID  = $ninjaLights.id
    $selector = 'id:' + $ninjaID
    $fullURL  = $baseurl + $selector + '/state'

    $payloadBuilder = "{
                    `"power`": `"$state`",
                    `"color`": `"$color`",
                    `"brightness`" : $brightness 
                    }"

    Write-Host "Changing light to:" -ForegroundColor $foregroundcolor
    Write-Host `t"State     :" $state
    Write-Host `t"Color     :" $color
    Write-Host `t"Brightness:" ($brightness * 100)"%" `n

    $stateReturn = Invoke-RestMethod -headers $headers -uri $fullURL -Method Put -Body $payloadBuilder
    
    Write-Host "API status:" -ForegroundColor $foregroundcolor
    Write-Host `t"Light :" $stateReturn.results.label
    Write-Host `t"Status:" $stateReturn.results.status `n
    
    
}

Switch ($action) {
    
    'setstate' { Change-LightState -state $state -color $color -brightness $brightness -selector $selector }
    
    'fluxtest' { 
        
        $originalBrightness = $ninjaLights.Brightness
        $originalColor      = $ninjalights.Color
        $originalState      = $ninjalights.Power
        $colorString        = "hue:" + $originalcolor.hue + " saturation:" + $originalcolor.saturation + " kelvin:" + $originalColor.Kelvin       
          
        $i = 0
        
        While ($i -le 20) {
            
            $color              = Get-Random $colors
            [double]$brightness = "{0:n2}" -f (Get-Random 0.99)
 
            Change-LightState -color $color -brightness $brightness -selector $selector -state $state
            Start-Sleep -seconds 1
            $i++
            
        }
        
        Change-LightState -state $originalState -color $colorString -brightness $originalBrightness -selector $selector  
        
    } 
    
    'flashcolor' {
        
        $originalBrightness = $ninjaLights.Brightness
        $originalColor      = $ninjalights.Color
        $originalState      = $ninjalights.Power
        $colorString        = "hue:" + $originalcolor.hue + " saturation:" + $originalcolor.saturation + " kelvin:" + $originalColor.Kelvin
        
        Change-LightState -state $state -color $color -brightness $brightness -selector $selector
        Start-Sleep -Seconds 1
        
        Change-LightState -state $originalState -color $colorString -brightness $originalBrightness -selector $selector
        Start-Sleep -Seconds 1
                
        Change-LightState -state $state -color $color -brightness $brightness -selector $selector
        Start-Sleep -Seconds 1
        
        Change-LightState -state $originalState -color $colorString -brightness $originalBrightness -selector $selector
        Start-Sleep -Seconds 1        
        
        Change-LightState -state $state -color $color -brightness $brightness -selector $selector
        Start-Sleep -Seconds 1
        
        Change-LightState -state $originalState -color $colorString -brightness $originalBrightness -selector $selector
                        
    }
}    
    
    
}

Get-Weather 