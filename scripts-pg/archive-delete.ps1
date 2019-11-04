Import-Module pg-module -Force

$ScriptItem = Get-Item -Path $PSCommandPath

$LogDir = Add-PgPath -Path $ScriptItem.DirectoryName -AddPath logs
$Log = Get-PgLog -Dir $LogDir -Name 'DeleteBackup'

Out-PgLog -Log $Log -Mark 'Start' -Text 'Search last actual backup'

# GET DELETE CONFIG SETTINGS
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
$WalThresholdName = 'walbackup-' + $ThresholdDate.ToString('yyyyMMdd-HHmmss')

Out-PgLog -Log $Log -Mark 'Info' -Text ('threshold date: ' + $ThresholdDate.ToString('dd.MM.yyyy HH:mm'))

# GET LAST BACKUP POINT (NOT TO DELETE)
$LastBackupPoint = Get-ChildItem -Path $ScriptConfigWal.archive -Filter 'walbackup-????????-??????.*.backup.*' -File -Recurse `
| Where-Object -FilterScript {$_.Name -gt $WalThresholdName} | Sort-Object -Property Name -Descending | Select-Object -Last 1

if ($LastBackupPoint.count -eq 0) {
    Out-PgLog -Log $Log -Mark 'End' -Text 'No last backup point to keep'
    return
}

Out-PgLog -Log $Log -Mark 'Info' -Text ('Last backup point to keep: ' + $LastBackupPoint.FullName)

$LastBackupPointItem = $LastBackupPoint[0]
$BackupPointPattern = '(?<prefix>walbackup-\d{8}-\d{6})\.(?<wal>[0-9a-fA-F]{24})\.(?<point>[0-9a-fA-F]{8})\.backup\.(?<ext>\w+)'

if ($LastBackupPointItem.Name -match $BackupPointPattern) {
    $BackupPointPrefix = $Matches.prefix
    $WalName = $Matches.wal
    $BackupPoint = $Matches.label
    $BackupExt = $Matches.ext
}
else {
    Out-PgLog -Log $Log -Mark 'Error' -Text 'Bad backup name'
    return
}

# GET LAST WAL POINT (NOT TO DELETE): delete all prefer wal.
$LastWal = Get-ChildItem -Path $ScriptConfigWal.archive -Filter ('walbackup-????????-??????.' + $WalName + '.*') -File -Recurse `
| Where-Object -FilterScript {$_.Name -lt $BackupPointPrefix} | Sort-Object -Property Name -Descending | Select-Object -First 1

$WalPattern = '(?<prefix>walbackup-\d{8}-\d{6})\.(?<wal>[0-9a-fA-F]{24})\.(?<ext>\w+)'

$WalPrefix = ''
if ($LastWal.count -gt 0) {
    $LastWalItem = $LastWal[0]
    Out-PgLog -Log $Log -Mark 'Info' -Text ('Last wal to keep ' + $LastWalItem.FullName)
    if ($LastWalItem.FullName -match $WalPattern) {
        $WalPrefix = $Matches.prefix
    }
    else {
        Out-PgLog -Log $Log -Mark 'Error' -Text 'Bad backup name'
        return       
    }
}
else {
    Out-PgLog -Log $Log -Mark 'Info' -Text 'No wal prefer last backup'
}

if ([String]::IsNullOrEmpty($WalPrefix)) {
    $WalPrefix = $BackupPointPrefix
}

# DELETE BACKUP
Out-PgLog -Log $Log -Mark 'DeleteBak' -Text 'Start'

$BakPrefix = $BackupPointPrefix -replace 'walbackup-', 'basebackup-'

$BackupItems = Get-ChildItem -Path $ScriptConfigBase.archive -Filter 'basebackup-????????-??????.*' -File -Recurse `
| Where-Object -FilterScript {($_.Name -lt $BakPrefix)} | Sort-Object -Property Name


if ($BackupItems.count -gt 1) {

    # Skip last backup - it is current last backup.
    $LastBackupToKeep = $BackupItems | Sort-Object -Property Name | Select-Object -Last 1

    Out-PgLog -Log $Log -Mark 'Info' -Text ('Last backup to keep: ' + $LastBackupToKeep.FullName)

    foreach ($BackupItem in $BackupItems) {
        if ($BackupItem -eq $LastBackupToKeep) {
            continue
        }
        Out-PgLog -Log $Log -Mark 'DeleteBak' -Text $BackupItem.FullName
        Remove-Item -Path $BackupItem.FullName -Force
        if (Test-Path -Path $BackupItem.FullName) {
            Out-PgLog -Log $Log -Mark 'Error' -Text 'Hasn''t deleted backup file'
        }
    }

}
else {
    Out-PgLog -Log $Log -Mark 'Info' -Text 'No backups to delete'
}

# DELETE WAL
Out-PgLog -Log $Log -Mark 'DeleteWal' -Text 'Start'

$WalItems = Get-ChildItem -Path $ScriptConfigWal.archive -Filter 'walbackup-????????-??????.*' -File -Recurse `
| Where-Object -FilterScript {($_.Name -lt $WalPrefix)} | Sort-Object -Property Name

if ($WalItems.count -gt 0) {
    foreach ($WalItem in $WalItems) {
        Out-PgLog -Log $Log -Mark 'DeleteWal' -Text $WalItem.FullName
        Remove-Item -Path $WalItem.FullName -Force
        if (Test-Path -Path $WalItem.FullName) {
            Out-PgLog -Log $Log -Mark 'Error' -Text 'Hasn''t deleted wal file'
        }
    }
}
else {
    Out-PgLog -Log $Log -Mark 'Info' -Text 'No backup wal to delete'
}

Out-PgLog -Log $Log -Mark 'End' -Text 'OK'
