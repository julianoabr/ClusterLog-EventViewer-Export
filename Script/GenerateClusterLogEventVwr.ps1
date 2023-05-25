#Requires -RunAsAdministrator
#Requires -Version 4.0

<#
.Synopsis:   Script to export Event Logs and Cluster Log to a shared folder
.Created by: Juliano Alves de Brito Ribeiro (julianoalvesbr@live.com)
.Version:    0.4
.Requirements:
    Have a hidden share named "ClusterLog$". After generate the logs, this script will copy to this. 
    
.Improvements:  Get Event Log of all nodes. 
                Validate Cluster Service
                Correct an Issue that remote log is not generated if C:\temp folder does not exists
.ToThink
The known energy of the sun should make it shine brighter and stronger over time. 
But that means that, if billions of years were true, the sun would have been weaker in the past. 
However, there is no evidence that the sun would have been weaker at any time in the earth's history.
Astronomers call this the "weak young sun paradox", but it is a paradox if the sun is the age the Bible says it is - about 6000 years old

Sarfati, Refuting, 169
#>

function Confirm-ClusSVCExists($ComputerName,$ServiceName)
{   
    if (Get-Service -ComputerName $ComputerName -Name $ServiceName -ErrorAction SilentlyContinue)
    {
        return $true
    }else
    {
    return $false
    }
}



function Export-MCSCLogEventVwr 
{
    
        [CmdletBinding()]
    Param
    (

        #Param Cluster Name Help Description
        [parameter(ValueFromPipeline=$True,
                   ValueFromPipelineByPropertyName=$True,
                   Mandatory=$true,
                   Position=0,
                   HelpMessage="Nome do Cluster")]
        [String]$clusterName,        


        #Param NodeName Help Description
        [parameter(ValueFromPipeline=$True,
                   ValueFromPipelineByPropertyName=$True,
                   HelpMessage="Name of Node")]
        [String]$NodeName,
        

        $tmpOutputPath = "$env:SystemDrive\Temp",


        # Param2 help description
        [parameter(HelpMessage="Cluster Nodes")]
        $clusterNodes = @(),

        [parameter(Mandatory=$false)]
        [string]$dataAtual=(Get-date -Format ddMMyyyy).ToString()

  
       )

$logFileList = "Application","System","Security" # Add Name of the Logfile (System, Application, etc)

#$clusterName = Read-Host -Prompt "Digite o Nome do Cluster que deseja exportar o Cluster Log e o EventViewer"

$clusterNodes = Get-Cluster -Name $clusterName | Get-ClusterNode | Select-Object -ExpandProperty Name

$outputPath = $tmpOutputPath

foreach ($clusterNode in $clusterNodes){

  $SVCExists = Confirm-ClusSVCExists -ServiceName 'ClusSvc' -ComputerName $clusterNode

  if ($SVCExists){
    
   Write-Output "Cluster Service is ok on node: $ClusterNode"

}#end of if
else
{
   Write-Output "Cluster Service is not ok on node: $ClusterNode"
      
}#end of else
    

}

#Verificar se o caminho para gravar os logs existe
if (Test-Path $tmpOutputPath){
    
    Write-Output "Path to save temporary files already exist. Let's continue..."

    Set-Location $OutputPath

    $tmpEVTX = Get-ChildItem -file | Where-Object -FilterScript {$_.Extension -like ".evtx"}

    $countEVTX = $tmpEVTX.Length

    if ($countEVTX -gt 0){

        $Hoursback = "-12"
        $CurrentDate = Get-Date
        #$DatetoDelete = $CurrentDate.AddDays($Daysback)
        $DatetoDelete = $CurrentDate.AddHours($Hoursback)
        Get-ChildItem -File | Where-Object { ($_.LastWriteTime -lt $DatetoDelete) -and ($_.Extension -eq ".evtx") } | Remove-Item
       
    }#end of IF
    
}#end of if
else{
    Write-Output "Path to save temporary files does not exists. I will create It"
    
    New-Item -Path "C:\" -Name "Temp" -ItemType "Directory" -Force -Verbose
    
    Start-Sleep -Milliseconds 300
      

}#end of else


foreach ($ClusterNode in $clusterNodes){

        $StringNode = $clusterNode.toString()
                
#Export Event Viewer Log Files
    foreach ($logFileName in $logFileList)
        {
            Write-Output "Generating the Logs of Node: $StringNode. Log Name: $logFileName ..."
        
            Start-Sleep -Milliseconds 300
        
            $exportFileName = $logFileName + "-" + $StringNode + "-" + (Get-Date -f ddMMyyyy) + ".evtx"
        
            $logFile = Get-WmiObject -ComputerName $StringNode -Class Win32_NTEventLogFile | Where-Object -FilterScript {$_.logfilename -eq $logFileName}
        
            #Test if Remote Folder Named Temp Exists
            if (Test-Path "\\$stringNode\C$\Temp"){
            
                $logFile.backupeventlog($outputpath + "\" + $exportFileName)
            
            }#End of If
            else{
                            
                New-Item -Path \\$StringNode\c$\ -ItemType Directory -Name "Temp" -Force -Verbose 

                $logFile.backupeventlog($outputpath + "\" + $exportFileName)
            
            }#End of Else
                               
    }#end foreach log

}#end foreach nodes

#COPY EVTX from Nodes to C:\TEMP
foreach ($ClusterNode in $clusterNodes){
    
    $StringNode = $clusterNode.ToString()

    Copy-Item -Path "\\$StringNode\C$\Temp\*.evtx" -Destination $outputPath -Force -Verbose
        
}#end FOREACH


$Hoursback = "-12"
$CurrentDate = Get-Date
#$DatetoDelete = $CurrentDate.AddDays($Daysback)
$DatetoDelete = $CurrentDate.AddHours($Hoursback)
Get-ChildItem $outputpath -File | Where-Object { ($_.LastWriteTime -lt $DatetoDelete) -and ($_.Extension -eq ".log") -and ($_.Name -like "*cluster*")} | Remove-Item
                  
#Generate ClusterLog
Write-Output "I will generate the Cluster Logs of the $ClusterName Now..."

foreach ($clusterNode in $clusterNodes){

    $StringNode = $clusterNode.ToString()

    Get-ClusterLog -Node $StringNode -Destination $outputPath -Verbose    

}#End of ForEach



#Create and Copy Logs to a Shared Folder
#####INPUT THE NAME OF YOUR SERVER HERE####
$SharedPC = "serverName"
$DriveLetter = "U"
$Path = "ClusterLog"

New-Item -Path \\$SharedPC\$Path$ -ItemType Directory -Name $clusterName-$dataAtual -Force -Verbose

Start-Sleep -Seconds 2 -Verbose

Move-Item -Path ".\*.log" -Destination \\$SharedPC\$Path$\$clusterName-$dataAtual -Verbose -Force
Move-Item -Path ".\*.evtx" -Destination \\$SharedPC\$Path$\$clusterName-$dataAtual -Verbose -Force


Write-Output "End of Script."


}#end of script

[string]$tmpClusterName = Read-Host "Write the Name of Cluster that you want to generate the logs"

Export-MCSCLogEventVwr -clusterName $tmpClusterName
