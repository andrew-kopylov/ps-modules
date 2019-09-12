Import-Module ($PSScriptRoot + '\modules\7z-module.ps1') -force

$Logs = 'C:\1c-logs'
$LogsArc = 'C:\archive-1Cv8Log'
$LogDays = 15

$ScriptFile = Get-Item -Path $PSCommandPath
$DataFile = $ScriptFile.DirectoryName + '\' + $ScriptFile.BaseName + '.json'

$DataText = ''
if (Test-Path -Path $DataFile) {
    $DataText = Get-Content -Path $DataFile
}

$Data = @()
if (-not [string]::IsNullOrEmpty($DataText)) {
    $Data = ConvertFrom-Json -InputObject $DataText
}

$LastLogFileName = $Data.LatsLogFileName
if ($LastLogFileName -eq $null) {
    $LastLogFileName = ''
}

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
        $LogFileArcName = $BaseLogsDir + '\' + $LogFile.BaseName + '.zip'
        if (Test-Path -Path $NewLogFileName) {
            Compress-7zArchive -Path $NewLogFileName -DestinationPath $LogFileArcName
        }

        # Delete log
        if (Test-Path -Path $LogFileArcName) {
            Remove-Item -Path $NewLogFileName
        }

    }
}