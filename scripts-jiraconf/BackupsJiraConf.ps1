Import-Module ($PSScriptRoot + '\modules\7z-module.ps1') -Force

$ConfBackupSize_Percent = 50
$JiraBackupSize_Percent = 40
$PerfMonSize_Percent = 2

$BackupDir = 'D:\backup'
$BackupVolume = (Get-Item -Path $BackupDir).Root.Name

$JiraAppData = 'C:\Program Files\Atlassian\Application Data\JIRA'

$JiraBackupExport = $BackupDir + '\jira\export'
if (-not (Test-Path -Path $JiraBackupExport)) {
    New-Item -Path $JiraBackupExport -ItemType 'Directory' -Force
}

$JiraBackupData = $BackupDir + '\jira\data'
if (-not (Test-Path -Path $JiraBackupData)) {
    New-Item -Path $JiraBackupData -ItemType 'Directory' -Force
}

# Move Jira Export to Backup
Move-Item -Path ($JiraAppData + '\Export\*') -Destination $JiraBackupExport

# Backup Jira Data
$BackupDateTime = (Get-Date).ToString('yyyyMMdd-HHmm')
Compress-7zArchive -Path ('"' + $JiraAppData + '\Data"') -DestinationPath ($JiraBackupData + '\data-' + $BackupDateTime + '.7z')

# Calculate max size of backup directories.
$Volume = Get-WmiObject -Class win32_volume | Where-Object -FilterScript {$_.Name -eq $BackupVolume} | Select-Object -First 1
$JiraBackupMaxSize = $Volume.Capacity * $JiraBackupSize_Percent / 100
$ConfBackupMaxSize = $Volume.Capacity * $ConfBackupSize_Percent / 100
$PerfMonMaxSize = $Volume.Capacity * $PerfMonSize_Percent / 100

# Release Jira backup dir
$ReleaseDir = $BackupDir + '\jira'
$ReleaseDirMaxSize = $JiraBackupMaxSize
$ReleaseDirSize = (Get-ChildItem -Path $ReleaseDir -Recurse | Measure-Object -Property length -Sum).Sum
$SpaceForRelease = ($ReleaseDirSize - $ReleaseDirMaxSize)
if ($ReleaseDirMaxSize -gt 0 -and $SpaceForRelease -gt 0) {
    $ItemsForRelease = Get-ChildItem -Path $ReleaseDir -Recurse -File | Sort-Object -Property 'CreationTime'
    foreach ($Item in $ItemsForRelease) {
        if ($SpaceForRelease -le 0) {
            break
        }
        $SpaceForRelease -= $Item.Length
        Remove-Item -Path $Item.FullName
    }
}

# Release Confluence backup dir
$ReleaseDir = $BackupDir + '\confluence'
$ReleaseDirMaxSize = $ConfBackupMaxSize
$ReleaseDirSize = (Get-ChildItem -Path $ReleaseDir -Recurse | Measure-Object -Property length -Sum).Sum
$SpaceForRelease = $ReleaseDirSize - $ReleaseDirMaxSize
if ($ReleaseDirMaxSize -gt 0 -and $SpaceForRelease -gt 0) {
    $ItemsForRelease = Get-ChildItem -Path $ReleaseDir -Recurse -File | Sort-Object -Property 'CreationTime'
    foreach ($Item in $ItemsForRelease) {
        if ($SpaceForRelease -le 0) {
            break
        }
        $SpaceForRelease -= $Item.Length
        Remove-Item -Path $Item.FullName
    }
}

# Release PerfMon reports
$ReleaseDir = 'D:\perfmon'
$ReleaseDirMaxSize = $PerfMonMaxSize
$ReleaseDirSize = (Get-ChildItem -Path $ReleaseDir -Recurse | Measure-Object -Property length -Sum).Sum
$SpaceForRelease = $ReleaseDirSize - $ReleaseDirMaxSize
if ($ReleaseDirMaxSize -gt 0 -and $SpaceForRelease -gt 0) {
    $ItemsForRelease = Get-ChildItem -Path $ReleaseDir -Recurse -File | Sort-Object -Property 'CreationTime'
    foreach ($Item in $ItemsForRelease) {
        if ($SpaceForRelease -le 0) {
            break
        }
        $SpaceForRelease -= $Item.Length
        Remove-Item -Path $Item.Directory.FullName -Recurse
    }
}
