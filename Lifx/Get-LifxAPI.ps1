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
            [double]$brightness = "{0:n2}" -f (Get-Random -Maximum 1 -Minimum 0.00)
 
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