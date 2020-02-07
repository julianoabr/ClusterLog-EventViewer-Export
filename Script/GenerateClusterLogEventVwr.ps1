#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.Synopsis:   Script to export Event Logs and Cluster Log to a shared folder
.Created by: Juliano Alves de Brito Ribeiro (julianoalvesbr@live.com)
.Version:    0.1
.Requirements:
#>


# Config
$logFileList = @()
$logFileList = "Application","System","Security" # Add Name of the Logfile (System, Application, etc)
$outputpath = "C:\temp\" # Add Path, needs to end with a backsplash
[string]$PCname = $env:COMPUTERNAME


if (Test-Path $outputpath){
    Write-Output "O caminho para salvar o arquivo já existe. Continuarei o script..."
}else{
    Write-Output "O caminho para salvar o arquivo não existe. Criarei...."
    New-Item -Path "c:\" -Name "Temp" -ItemType "Directory" -Force -Verbose 

}

Start-Sleep -Seconds 3

Write-Output "Would you like to delete old evtx files in path $outputpath before continue (Default is No)" -ForegroundColor Yellow 
    $ReadAnswer = Read-Host " ( y / n ) " 
    Switch ($ReadAnswer) 
     { 
       Y {
       Write-Output "Yes, I will delete now"
       $Daysback = "-2"
       $Hoursback = "-12"
       $CurrentDate = Get-Date
       #$DatetoDelete = $CurrentDate.AddDays($Daysback)
       $DatetoDelete = $CurrentDate.AddHours($Hoursback)
       Get-ChildItem $outputpath | Where-Object { ($_.LastWriteTime -lt $DatetoDelete) -and ($_.Extension -eq ".evtx") } | Remove-Item
       #Clear-Eventlog -LogName $logFileName
                  
       } 
       N {
          Write-Output "No, Let's Continue without delete"
          } 
       Default {Write-Output "Default, Let's continue without delete"} 
     } 



#Export Event Viewer Log Files
foreach ($logFileName in $logFileList)
    {
    Write-Output "Gerando os logs de $logFileName ..."
    Start-Sleep -Seconds 2
    $exportFileName = $logFileName + "-" + $PCname + (get-date -f yyyyMMdd) + ".evtx"
    $logFile = Get-WmiObject -Class Win32_NTEventLogFile | Where-Object -FilterScript {$_.logfilename -eq $logFileName}
    $logFile.backupeventlog($outputpath + $exportFileName)

}

#Ask if user wants to delete old cluster logs
Write-Output "Would you like to delete old ClusterLog files in path $outputpath before continue (Default is No)" -ForegroundColor Yellow 
    $ReadAnswer = Read-Host " ( y / n ) " 
    Switch ($ReadAnswer) 
     { 
       Y {
       Write-Output "Yes, I will delete now"
       $Daysback = "-2"
       $Hoursback = "-6"
       $CurrentDate = Get-Date
       #$DatetoDelete = $CurrentDate.AddDays($Daysback)
       $DatetoDelete = $CurrentDate.AddHours($Hoursback)
       Get-ChildItem $outputpath | Where-Object { ($_.LastWriteTime -lt $DatetoDelete) -and ($_.Extension -eq ".log") -and ($_.Name -like "*cluster*")} | Remove-Item
       #Clear-Eventlog -LogName $logFileName
                  
       } 
       N {
          Write-Output "No, Let's Continue without delete"
          } 
       Default {Write-Output "Default, Let's continue without delete"} 
     } 


#Generate ClusterLog
Write-Output "I will generate the cluster logs now..."

Get-ClusterLog -Destination $outputpath -Verbose

Start-Sleep -Seconds 3 -Verbose


#Create and Copy Logs to a Shared Folder

$SharedPC = "servername"
$DriveLetter = "C"
$Path = "clusterlog$"
New-Item -Path \\$SharedPC\$DriveLetter$\$Path -ItemType Directory -Name $PCname -Force -Verbose

Start-Sleep -Seconds 3 -Verbose

Set-Location "$env:SystemDrive\TEMP"

Move-Item -Path ".\*.log" -Destination \\$SharedPC\$DriveLetter$\$Path\$PCName -Verbose -Force
Move-Item -Path ".\*.evtx" -Destination \\$SharedPC\$DriveLetter$\$Path\$PCName -Verbose -Force


Write-Output "Fim do Script"
