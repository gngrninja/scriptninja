<#   
.SYNOPSIS   
   This script takes quests from the SuperBetter book and returns or emails the current day's quest.
.DESCRIPTION 
   You can use this script to return the current day's quest as well as have it emailed out. 
   
   File / Variable structure:
   
   $questLog imports a csv of quests with the following headers: "Day,Quest,Notes,Boosts,Completion"
   $runLog imports a csv of the scripts progress. If you would like to start on 12/28/15 as an example, you'd put the following first lines (including headers): DateTime,Day,Completed
"12/28/2015","1","No"
   $emailPass     = a secure hash of your email password
   $emailUser     = your username for email. This script uses gmail.
   $emailFrom     = the from address of your email.
   $mailingList   = this imports the emails from mailinglist.txt 
   $SMTPserver    = This is set to gmail's servers currently. Feel free to change it.
   $powerups      = Imports contents of powerups.txt
   $badguys       = Imports contents of badguys.txt
   $challengeDays = Default is set to 21, feel free to change if your challenge has more or less days.
   
   To get this script working, setup a daily scheduled task to run this script with -updateLog $true and -sendEmail $true arguments.
   
   TODO: Create runLog and questLog example files if script is run and they do not exist.
.PARAMETER updateLog
    Updates the log file so the next day works properly if $true.
.PARAMETER sendEmail 
    Sends an email to $mailingList with the current day's quest if $true.
.PARAMETER getQuest
    Return the current day's quest if $true.
.PARAMETER testEmail
    If you specify $true for this it will not only display what would be emailed and where it would be emailed, no email would be sent.
	NOTE: You'll need to also specify $sendEmail $true to use testEmail.
.PARAMETER sendDiagEml
    If you pass an email address to this parameter it will send it a list of all the variables and their values.
.NOTES   
    Name: superbetter.ps1
    Author: Ginger Ninja (Mike Roberts)
    DateCreated: 12/29/2015
.LINK  
    http://www.gngrninja.com      
.EXAMPLE   
    .\superbetter.ps1 -updateLog $true -sendEmail $true
 .EXAMPLE
    $todayQuest = .\superbetter.ps1 -getQuest $true
.EXAMPLE 
	.\superbetter.ps1 -sendEmail $true -testEmail $true
.EXAMPLE 
	.\superbetter.ps1 -sendDiagEml "email@address.com"    
#> 
[cmdletbinding()]
Param(
    [boolean]
    $updateLog,
    
    [boolean]
    $sendEmail,
     
    [boolean] 
    $getQuest,
    
    [boolean]
    $testEmail,
    
    [string]
    $sendDiagEml
)

#Variables used throughout the script.
$todayDate        = (Get-Date).ToShortDateString()
$tomorrowDate     = (Get-Date).AddDays(1).ToShortDateString()
#These paths work so as long as you store the script here and specify the same directory as the working directory.
$runLog           = Import-CSV .\runlog.csv
$questLog         = Import-CSV .\ninjabody.csv
#This sets up the hashtable for the CSV export of the runlog.
$logHeaders       = @{
    "DateTime"  = '' 
    "Day"       = ''
    "Completed" = '' 
} 

#Run the next commented out line to get your machine-key encrypted password and output it in emlpassword.txt
#"password" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File .\emlpassword.txt
$emailPass    = Get-Content .\emlpassword.txt | ConvertTo-SecureString  
#Setup the email username and from address.
$emailUser    = 'ginjascript'
$emailFrom    = 'ginjascript@gmail.com'
$emlSignature = '-Ginger Ninja'
#Specify an array of email addresses to send an email to.
[array]$mailingList  = Get-Content .\mailinglist.txt
#Specify the mail server.
$SMTPServer   = 'smtp.gmail.com'
#Specify the array of powerups and badguys. 
[array]$powerups     = Get-Content .\powerups.txt
[array]$badguys      = Get-Content .\badguys.txt
#Specify the number of challenge days. This should be the last "day" of the challenge in the CSV $questLog
[int]$challengeDays = 21

#This function returns the current days quest as gathered from the runlog and questlog.
function Get-DayQuest {
    [cmdletbinding()]
    param()
    
    [int]$questDay   = ($runLog | Where-Object {$_.DateTime -eq $todayDate} | Select-Object Day).Day
    
    $questToday = $questLog | Where-Object {$_.Day -eq $questDay} 
    
    Return $questToday
    
}

#This function updates the quest log so the quests progress for the next day.
function Log-DayQuest {
    [cmdletbinding()]
    param($todayDate,$tomorrowDate,$logHeaders)
    
    [int]$questDay   = ($runLog | Where-Object {$_.DateTime -eq $todayDate} | Select-Object Day).Day
    if ($questDay -lt $challengeDays+1) {
    
        if (($runLog | Where-Object {$_.DateTime -eq $todayDate} | Select-Object Completed).Completed -eq "Yes") {
    
            Write-Host "Log already updated!"
 
        } Elseif ($runLog | Where-Object {$_.DateTime -eq $todayDate})  { 

            [int]$day = ($runLog | Where-Object {$_.DateTime -eq $todayDate} | Select-Object Day).Day
        
            #Log today as completed
            ($runLog | Where-Object {$_.DateTime -eq $todayDate}).Completed = "Yes"        

            $runLog | Export-CSV .\runlog.csv -NoTypeInformation
          
            #Log tomorrow as not completed
            
            $logHeaders.DateTime  = $tomorrowDate
            $logheaders.Day       = $day+1
            $logheaders.Completed = "No"

            $newrow = New-Object PSObject -Property $logHeaders
            Export-CSV .\runLog.csv -InputObject $newrow -append -Force
        
        } elseif($runLog | Where-Object {$_.DateTime -eq $todayDate} -eq $null) {
            
            Write-Host "No entry for today... creating entry and updating"
            [int]$day = ($runlog[$runlog.count-1]).day 
            $logHeaders.DateTime  = $todayDate
            $logheaders.Day       = $day+1
            $logheaders.Completed = "Yes"
            
            $newrow = New-Object PSObject -Property $logHeaders
            Export-CSV .\runLog.csv -InputObject $newrow -append -Force

        }
    }
}

#This function simply takes a few parameters and sends the email.
function Send-DailyQuestEmail {
    [cmdletbinding()]
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [string]
    $To,
    
    [string]
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    $Subject,
    
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    $Body)

    if (!$to)      {Write-Error "No recipient specified";break}
    if (!$subject) {Write-Error "No subject specified";break}
    if (!$body)    {Write-Error "No body specified";break}
   
       
    $SMTPClient  = New-Object Net.Mail.SmtpClient($SmtpServer, 587) 
    $SMTPMessage = New-Object System.Net.Mail.MailMessage($EmailFrom,$To,$Subject,$Body)

    $SMTPClient.EnableSsl = $true 
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($emailUser,$emailPass); 
    
    $SMTPClient.Send($SMTPMessage)

}

#Let's parse out the parameters
if ($sendEmail) {
    
    $questInfo       = Get-DayQuest
    [int]$questDay   = $questInfo.Day 
    $questShort      = $questInfo.Quest 
    
    if ($questDay -lt $challengeDays+1) {
    
        $Subject = "Ninja body: Day " + $questDay + " (" + $questShort + ")"
        
        $body = "Welcome to the SuperBetter Ninja Body challenge!"
        $body += "`n"
        $body += "`n"
        $body += "This is day " + $questDay + "!"
        $body += "`n"
        $body += "`n"
        $body += "The quest for today is: " + $questShort
        $body += "`n"
        $body += "`n"
        $body +="This quest boosts: " + $questInfo.Boosts
        $body += "`n"
        $body += "`n"
        $body += "Quest information: " 
        $body += "`n"
        $body += $questInfo.Notes
        $body += "`n"
        $body += "`n"
        $body += "To complete this quest:"
        $body += "`n"
        $body += $questInfo.Completion
        $body += "`n"
        $body += "`n"
        $body += "`n"
        $body += "`n"
        $body += "PowerUps:"
        $body += "`n"
    
        foreach ($up in $powerups) {
        
            $body += $up
            $body += "`n"
        
        }
    
        $body += "`n"
        $body += "`n"
        $body += "Bad guys:"
        $body += "`n"
    
        foreach ($guy in $badguys) {
        
            $body += $guy
            $body += "`n"
        
        }
    
        $body += "`n"
        $body += "`n"
        $body += "`n"
        $body += "Have a great day!"
        $body += "`n"
        $body += $emlSignature 
        $body = $body | Out-String 
         
        #If you specify $true for the testEmail parameter then it wont email
        #Instead it will show you what it would email. 
        if ($testEmail -ne $true) {
            foreach ($address in $mailingList) {
         
                Send-DailyQuestEmail -To $address -Subject $subject -Body $body  
            
        }
        
        } else {
            
            Write-Host -NoNewLine "Sending as: " -ForegroundColor Green
            Write-Host -NoNewLine $emailUser 
            Write-Host -NoNewLine " Email Address: " -ForegroundColor Green 
            Write-Host -NoNewLine $emailFrom `n
            Write-Host "Sending to: "`n -foregroundcolor Green
            foreach ($address in $mailingList){Write-Host `t $address}
            Write-Host -NoNewLine `n"Subject: " -foregroundcolor Green 
            Write-Host -NoNewLine $subject`n`n 
            Write-Host "Body:"`n -foregroundcolor Green
            Write-Host $body
            
    }
    }    
}

function Send-DiagnosticEmail {
    [cmdletbinding()]
    param(
        [string]
        $emailAddress
    )
    
    $subject = "Superbetter PS Script Diagnostics"
    
    $body += "Superbetter script diagnostics"  
    $body += "`n"
    $body += "`n"
    $body += "Variables:"
    $body += "`n"
    $body += "`n"
    $body += '$todayDate'
	$body += "`n"
    $body += "`n"
    $body += $todayDate
	$body += "`n"
    $body += "`n"
    $body += '$tomorrowDate'
	$body += "`n"
    $body += "`n"
    $body += $tomorrowDate
	$body += "`n"
    $body += "`n"
    $body += '$runLog'
	$body += "`n"
    $body += "`n"
    $body += $runLog | Out-String
	$body += "`n"
    $body += "`n"
    $body += '$questLog'
	$body += "`n"
    $body += "`n"
    $body += $questLog | Out-String
	$body += "`n"
	$body += "`n"
    $body += '$logHeaders'
	$body += "`n"
    $body += "`n"
    $body += $logHeaders | Out-String
	$body += "`n"
    $body += "`n"
    $body += '$emailUser'
	$body += "`n"
    $body += "`n"
    $body += $emailUser 
	$body += "`n"
	$body += "`n"
    $body += '$emailPass'
	$body += "`n"
    $body += "`n"
    $body += $emailPass | ConvertFrom-SecureString | Out-String
	$body += "`n"
	$body += "`n"
    $body += '$emailFrom'
	$body += "`n"
	$body += "`n"
    $body += $emailFrom
	$body += "`n"
	$body += "`n"
    $body += '$SmtpServer'
	$body += "`n"
	$body += "`n"
    $body += $smtpServer
	$body += "`n"
    $body += "`n"
    $body += '$mailingList'
	$body += "`n"
	$body += "`n"
    $body += $mailingList | Out-String
	$body += "`n"
    $body += "`n"
    $body += '$badguys'
	$body += "`n"
	$body += "`n"
    $body += $badguys | Out-String
	$body += "`n"
	$body += "`n"
    $body += '$powerUps'
	$body += "`n"
    $body += "`n"	
    $body += $powerUps | Out-String
	$body += "`n"
    $body += "`n"
    $body += '$challengeDays'
    $body += "`n"	
    $body += $challengeDays
	$body += "`n"
    $body += "`n"
	$body += "`n"
	$body += "`n"
    $body += $emlSignature 
    $body = $body | Out-String 

    Send-DailyQuestEmail -to $emailAddress -subject $subject -body $body
    
}
if ($updateLog)   {Log-DayQuest $todayDate $tomorrowDate $logHeaders}
if ($getQuest)    {Get-DayQuest}
if ($sendDiagEml) {Send-DiagnosticEmail -emailAddress $sendDiagEml}