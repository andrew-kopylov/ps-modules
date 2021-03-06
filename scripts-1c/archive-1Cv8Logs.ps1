﻿Import-Module 7z-module -force

$ScriptItem = $PSCommandPath | Get-Item 

# Read script config parameters
$ScriptConfig = Get-Content -Path ($ScriptItem.DirectoryName + '\config\' + $ScriptItem.BaseName + '.json') -Raw | ConvertFrom-Json
$SrvInfo = $ScriptConfig.srvinfo
$LogDays = $ScriptConfig.logsDaysToArch
$LogsArc = $ScriptConfig.logsArch
$ArchExt = $ScriptConfig.archExt

$List1Cv8Log = Get-ChildItem -Path ($SrvInfo + '\*') -Directory -Include '1Cv8Log' -Recurse
foreach ($Item1Cv8Log in $List1Cv8Log) {
    
    $BaseId = $Item1Cv8Log.Parent.Name
    $MaxLogFileName = ((Get-Date).AddDays(-$LogDays)).ToString('yyyyMMdd')

    $BaseLogsDir = $LogsArc + '\' + $BaseId

    if (-not (Test-Path -Path $BaseLogsDir)) {
        $NewItem = New-Item -Path $BaseLogsDir -ItemType Directory -Force
    }

    $ListLogFiles = Get-ChildItem -Path ($Item1Cv8Log.FullName + '\*') -File -Include '*.lgp' | Where-Object -FilterScript {$_.BaseName -lt $MaxLogFileName} | Sort-Object -Property 'name'
    foreach ($LogFile in $ListLogFiles) {

        # Move log
        $NewLogFileName = $BaseLogsDir + '\' + $LogFile.Name        
        Move-Item -Path $LogFile.FullName -Destination $NewLogFileName

        # Create archive
        $LogFileArcName = $BaseLogsDir + '\' + $LogFile.BaseName + '.' + $ArchExt
        if (Test-Path -Path $NewLogFileName) {
            Compress-7zArchive -Path $NewLogFileName -DestinationPath $LogFileArcName
        }

        # Delete log
        if (Test-Path -Path $LogFileArcName) {
            Remove-Item -Path $NewLogFileName
        }

    }
}
