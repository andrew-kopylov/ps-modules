Import-Module ($PSScriptRoot + '\modules\7z-module.ps1') -Force

$ScriptItem = $PSCommandPath | Get-Item 

# Read script config parameters
$ScriptConfig = Get-Content -Path ($ScriptItem.DirectoryName + '\configs\' + $ScriptItem.BaseName + '.json') -Raw | ConvertFrom-Json
$Logs = $ScriptConfig.logsDir
$LogsArch = $ScriptConfig.logsArch
$StoreDays = $ScriptConfig.storeDays
$ArchExt = $ScriptConfig.archExt

$MinLogsDate = (Get-Date).AddDays(-$StoreDays)
$MinLogsName = $MinLogsDate.ToString('yyMMddHH')
$CurLogFileName = (Get-Date).ToString('yyMMddHH')

# Delete old acrhive files 
if (Test-Path -Path $LogsArch) {
    $OldArchFiles = Get-ChildItem -Path $LogsArch -File -Filter ('*.' + $ArchExt) `
        | Where-Object -FilterScript {$_.BaseName -lt $MinLogsName}
    foreach ($ArchFile in $OldArchFiles) {
        Remove-Item -Path $ArchFile.FullName -Force
    }
    # Get last archived log file name.
    $LastArchFile = Get-ChildItem -Path $LogsArch -File -Filter ('*.' + $ArchExt) `
        | Sort-Object -Property BaseName -Descending `
        | Select-Object -First 1 
    $LastArchFileBaseName = $LastArchFile[0].BaseName
} 
else {
    $LastArchFileBaseName = ''
}

if ([string]::IsNullOrEmpty($LastArchFileBaseName)) {$LastArchFileBaseName = ''}

# Get all log files with min-max filter
$LogFiles = Get-ChildItem -Path $Logs -Recurse -File -Filter '*.log' `
    | Where-Object -FilterScript {$_.BaseName -ge $MinLogsName -and $_.BaseName -gt $LastArchFileBaseName -and $_.BaseName -lt $CurLogFileName} `
    | Sort-Object -Property 'BaseName'

# Get unique log names set
$UniqueBaseNames = $LogFiles | Select-Object -Property 'BaseName' -Unique

# Create archive directory
if ($UniqueBaseNames.Count -gt 0 -and -not (Test-Path -Path $LogsArch)) {
    New-Item -Path $LogsArch -ItemType Directory -Force
}

# Archive Logs
foreach ($BaseName in $UniqueBaseNames) {
    $ArchiveName = $LogsArch + '\' + $BaseName.BaseName + '.' + $ArchExt
    $LogFilesMask = $Logs + '\*' + $BaseName.BaseName + '.log'
    Compress-7zArchive -Path $LogFilesMask -DestinationPath $ArchiveName -Recurse
}
