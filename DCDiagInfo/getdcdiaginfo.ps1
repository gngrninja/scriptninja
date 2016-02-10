<#   
.SYNOPSIS   
   Display DCDiag information on domain controllers.
.DESCRIPTION 
   Display DCDiag information on domain controllers. $adminCredential and $ourDCs should be set externally.
   $ourDCs should be an array of all your domain controllers. This function will attempt to set it if it is not set via QAD tools.
   $adminCredential should contain a credential object that has access to the DCs. This function will prompt for credentials if not set.
   If the all dc option is used along side -Type full, it will return an object you can manipulate.
.PARAMETER DC 
    Specify the DC you'd like to run dcdiag on. Use "all" for all DCs.
.PARAMETER Type 
    Specify the type of information you'd like to see. Default is "error". You can specify "full"           
.NOTES   
    Name: Get-DCDiagInfo
    Author: Ginger Ninja (Mike Roberts)
    DateCreated: 12/08/2015
.LINK  
    http://www.gngrninja.com/script-ninja/2015/12/29/powershell-get-dcdiag-commandlet-for-getting-dc-diagnostic-information      
.EXAMPLE   
    Get-DCDiagInfo -DC idcprddc1 -Type full
    $DCDiagInfo = Get-DCDiagInfo -DC all -type full -Verbose
#>  
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [String]
        $DC,
        
        [Parameter()]
        [ValidateScript({$_ -like "Full" -xor $_ -like "Error"})]
        [String]
        $Type,
        
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]
        $Utility
        )
    
    try {
        
    if (!$ourDCs) {
        
        $ourDCs = get-QADComputer -computerRole 'DomainController'
    
    }
    
    if (!$adminCredential) {
        
        $adminCredential = Get-Credential -Message "Please enter Domain Admin credentials"
        
    }
    
    
    Switch ($dc) {
    
    {$_ -eq $null -or $_ -like "*all*" -or $_ -eq ""} {
    
        Switch ($type) {  
            
        {$_ -like "*error*" -or $_ -like $null} {  
             
            [array]$dcErrors = $null
            $i               = 0
            
            foreach ($d in $ourDCs){
            
                $name = $d.Name    
                
                Write-Verbose "Domain controller: $name"
                
                Write-Progress -Activity "Connecting to DC and running dcdiag..." -Status "Current DC: $name" -PercentComplete ($i/$ourDCs.Count*100)
                
                $session = New-PSSession -ComputerName $d.Name -Credential $adminCredential
                
                Write-Verbose "Established PSSession..."
                
                $dcdiag  = Invoke-Command -Session $session -Command  { dcdiag }
                
                Write-Verbose "dcdiag command ran via Invoke-Command..."
            
                if ($dcdiag | ?{$_ -like "*failed test*"}) {
                    
                    Write-Verbose "Failure detected!"
                    $failed = $dcdiag | ?{$_ -like "*failed test*"}
                    Write-Verbose $failed
                    [array]$dcErrors += $failed.Replace(".","").Trim("")
            
                } else {
                
                    $name = $d.Name    
                
                    Write-Verbose "$name passed!"
                    
                }
                
                
                Remove-PSSession -Session $session
                
                Write-Verbose "PSSession closed to: $name"
                $i++
            }
            
            Return $dcErrors
        } 
            
        {$_ -like "*full*"}    {
            
            [array]$dcFull             = $null
            [array]$dcDiagObject       = $null
            $defaultDisplaySet         = 'Name','Error','Diag'
            $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
            $PSStandardMembers         = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
            $i                         = 0
            
            foreach ($d in $ourDCs){
                
                $diagError = $false
                $name      = $d.Name
                
                Write-Verbose "Domain controller: $name"
                
                Write-Progress -Activity "Connecting to DC and running dcdiag..." -Status "Current DC: $name" -PercentComplete ($i/$ourDCs.Count*100)
                
                $session = New-PSSession -ComputerName $d.Name -Credential $adminCredential
                
                Write-Verbose "Established PSSession..."
                
                $dcdiag  = Invoke-Command -Session $session -Command  { dcdiag }
                
                Write-Verbose "dcdiag command ran via Invoke-Command..."
                
                #out string
                $diagstring = $dcdiag | Out-String
                
                Write-Verbose $diagstring

                if ($diagstring -like "*failed*") {$diagError = $true}
                
                $dcDiagProperty  = @{Name=$name}
                $dcDiagProperty += @{Error=$diagError}
                $dcDiagProperty += @{Diag=$diagstring}
                $dcO             = New-Object PSObject -Property $dcDiagProperty
                $dcDiagObject   += $dcO
                
                Remove-PSSession -Session $session
                
                Write-Verbose "PSSession closed to: $name"
                
                $i++
            }
            
            $dcDiagObject.PSObject.TypeNames.Insert(0,'User.Information')
            $dcDiagObject | Add-Member MemberSet PSStandardMembers $PSStandardMembers
            
            Return $dcDiagObject
        
            }
        
        }
         break         
    }
   
   
    {$_ -notlike "*all*" -or $_ -notlike $null} {
   
        Switch ($type) {
        
        {$_ -like "*error*" -or $_ -like $null} {
        
            if (Get-ADDomainController $dc) { 
    
                Write-Host "Domain controller: " $dc `n -foregroundColor $foregroundColor
            
                $session = New-PSSession -ComputerName $dc -Credential $adminCredential
                $dcdiag  = Invoke-Command -Session $session -Command  { dcdiag }
       
                if ($dcdiag | ?{$_ -like "*failed test*"}) {
                
                    Write-Host "Failure detected!"
                
                    $failed = $dcdiag | ?{$_ -like "*failed test*"}
                
                    Write-Output $failed 
                
                } else { 
                
                    Write-Host $dc " passed!"
                
                }
                    
            Remove-PSSession -Session $session       

            } 
        }
        
        {$_ -like "full"} {
            
            if (Get-ADDomainController $dc) { 
    
                Write-Host "Domain controller: " $dc `n -foregroundColor $foregroundColor
            
                $session = New-PSSession -ComputerName $dc -Credential $adminCredential
                $dcdiag  = Invoke-Command -Session $session -Command  { dcdiag }
                $dcdiag     
                    
                Remove-PSSession -Session $session       

            }     
                
        }
        
    }
    
    }
    
    }
    
    }
    
    Catch  [System.Management.Automation.RuntimeException] {
      
        Write-Warning "Error occured: $_"
 
        
     }
    
    Finally { Write-Verbose "Get-DCDiagInfo function execution completed."}