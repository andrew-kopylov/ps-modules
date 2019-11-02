Import-Module pg-module -Force

$ScriptItem = Get-Item -Path $PSCommandPath

$LogDir = Add-PgPath -Path $ScriptItem.DirectoryName -AddPath logs
$Log = Get-PgLog -Dir $LogDir -Name 'DeleteBackup'

Out-PgLog -Log $Log -Mark 'Start' -Text 'Search last actual backup'

# Get config settings
$ScriptConfigFile = Add-PgPath -Path $ScriptItem.DirectoryName -AddPath config, ($ScriptItem.BaseName + '.json')
$ScriptConfigDelete = Get-Content -Path $ScriptConfigFile | ConvertFrom-Json

$ScriptConfigFile = Add-PgPath -Path $ScriptItem.DirectoryName -AddPath config, archive-base.json
$ScriptConfigBase = Get-Content -Path $ScriptConfigFile | ConvertFrom-Json

$ScriptConfigFile = Add-PgPath -Path $ScriptItem.DirectoryName -AddPath config, archive-wal.json
$ScriptConfigWal = Get-Content -Path $ScriptConfigFile | ConvertFrom-Json

$HoldDays = [int]$ScriptConfigDelete.Day
$HoldHours = [int]$ScriptConfigDelete.Hour
$HoldMinutes = [int]$ScriptConfigDelete.Minute
if (($HoldDays -eq 0) -and ($HoldHours -eq 0) -and ($HoldMinutes -eq 0)) {
    Out-PgLog -Log $Log -Mark 'Error' -Text 'No hold time'
}

Out-PgLog -Log $Log -Mark 'Info' -Text ('hold d' + $HoldDays + ' h' + $HoldHours + ' m' + $HoldMinutes)

$HoldTime = New-TimeSpan -Days $HoldDays -Hours $HoldHours -Minutes $HoldMinutes
$ThresholdDate = (Get-Date) - ($HoldTime)
$ThresholdName = 'walbackup-' + $ThresholdDate.ToString('yyyyMMdd-HHmmss')

Out-PgLog -Log $Log -Mark 'Info' -Text ('threshold date: ' + $ThresholdDate.ToString('dd.MM.yyyy HH:mm'))

$WalItems = Get-ChildItem -Path $ScriptConfigWal.archive -Filter 'walbackup-????????-??????.*.backup.*' -Recurse `
| Where-Object -FilterScript {$_.Name -gt $ThresholdName} | Sort-Object -Property Name -Descending | Select-Object -Last 1

if ($WalItems.count -eq 0) {
    Out-PgLog -Log $Log -Mark 'End' -Text 'No backup for delete'
    return
}

Out-PgLog -Log $Log -Mark 'LastBackup' -Text $WalItems.FullName

$WalBackupLabelItem = $WalItems[0]
$WalPattern = '(?<prefix>walbackup-\d{8}-\d{6})\.(?<wal>[0-9a-fA-F]{24})\.(?<label>[0-9a-fA-F]{8})\.backup\.(?<ext>\w+)'

if ($WalBackupLabelItem.Name -match $WalPattern) {
    $WalPrefix = $Matches.prefix
    $WalName = $Matches.wal
    $BackupLabel = $Matches.label
    $BackupExt = $Matches.ext
}
else {
    Out-PgLog -Log $Log -Mark 'info' -Text 'Bad backup name'
    return
}

Out-PgLog -Log $Log -Mark 'DeleteBak' -Text 'Start'

$BackupLabelItems = Get-ChildItem -Path $ScriptConfigWal.archive -Filter 'walbackup-????????-??????.*.backup.*' -Recurse `
| Where-Object -FilterScript {($_.Name -lt $WalPrefix)} | Sort-Object -Property Name -Descending | Select-Object -First 1
if ($BackupLabelItems.count -gt 0) {

    $BackupLabelItem = $BackupLabelItems[0]

    Out-PgLog -Log $Log -Mark 'DeleteBak' -Text ('Last backup label to delete: ' + $BackupLabelItem.FullName)

    if ($BackupLabelItem.Name -match $WalPattern) {
        $BakPrefix = $Matches.prefix
    }

    $BackupItems = Get-ChildItem -Path $ScriptConfigBase.archive -Filter 'basebackup-????????-??????.*' -Recurse `
    | Where-Object -FilterScript {($_.Name -lt $BakPrefix)} | Sort-Object -Property Name

    foreach ($BackupItem in $BackupItems) {
        Out-PgLog -Log $Log -Mark 'DeleteBak' -Text $BackupItem.FullName
        Remove-Item -Path $BackupItem.FullName -Force
        if (Test-Path -Path $BackupItem.FullName) {
            Out-PgLog -Log $Log -Mark 'Error' -Text 'Not deleted backup file'
        }
    }

}
else {
    Out-PgLog -Log $Log -Mark 'info' -Text 'No backup labels'
}


Out-PgLog -Log $Log -Mark 'DeleteWal' -Text 'Start'

$WalItems = Get-ChildItem -Path $ScriptConfigWal.archive -Filter 'walbackup-????????-??????.*' -Recurse `
| Where-Object -FilterScript {($_.Name -lt $WalPrefix) -and ($_.Name -notlike ('*' + $WalName + '*'))} | Sort-Object -Property Name

if ($WalItems.count -gt 0) {
    foreach ($WalItem in $WalItems) {
        Out-PgLog -Log $Log -Mark 'DeleteWal' -Text $WalItem.FullName
        Remove-Item -Path $WalItem.FullName -Force
        if (Test-Path -Path $WalItem.FullName) {
            Out-PgLog -Log $Log -Mark 'Error' -Text 'Not deleted wal file'
        }
    }
}
else {
    Out-PgLog -Log $Log -Mark 'info' -Text 'No backup wal'
}

Out-PgLog -Log $Log -Mark 'End' -Text 'OK'
