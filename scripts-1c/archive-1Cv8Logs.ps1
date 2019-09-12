
$SrvInfo = 'C:\Program Files\1cv8\srvinfo'
$LogsArc = 'C:\1Cv8Log-archive'
$LogDays = 15

$List1Cv8Log = Get-ChildItem -Path ($SrvInfo + '\*') -Directory -Include '1Cv8Log' -Recurse
foreach ($Item1Cv8Log in $List1Cv8Log) {
    
    $BaseId = $Item1Cv8Log.Parent.Name
    $MaxLogFileName = ((Get-Date).AddDays(-$logdays)).ToString('yyyyMMdd')

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
        $LogFileArcName = $BaseLogsDir + '\' + $LogFile.BaseName + '.zip'
        if (Test-Path -Path $NewLogFileName) {
            Compress-Archive -Path $NewLogFileName -DestinationPath $LogFileArcName
        }

        # Delete log
        if (Test-Path -Path $LogFileArcName) {
            Remove-Item -Path $NewLogFileName
        }

        break
    }
}