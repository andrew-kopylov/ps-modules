Import-Module 1c-module -Force
Import-Module 7z-module -Force

$RepDir = 'c:\repository'
$RepBackupDir = 'c:\repository-backups'
$StoreDays = 0

$RepNames = @('rep-dev', 'rep-release', 'rep-another')

foreach ($Rep in $RepNames) {

    $BackupDateFormat = 'yyMMddHHmmss'
    $BackupDate = (Get-Date).ToString($BackupDateFormat)
    $BackupName = "$RepBackupDir\$Rep-$BackupDate"
    $BackupArch = "$BackupName.7z"

    Backup-1CCR -Path $RepDir\$Rep -BackupPath $BackupName
    Compress-7zArchive -Path $BackupName -DestinationPath $BackupArch -CompressionLevel Fastest -Recurse

    if (Test-Path -Path $BackupArch) {
        Remove-Item -Path $BackupName -Recurse -Force
    }

    $MatchMask = "$Rep-\d{12}"
    $LastBaseName = "$Rep-" + (Get-Date).AddDays(-$StoreDays).ToString($BackupDateFormat)

    Get-ChildItem -Path $RepBackupDir -Filter "$Rep-*.7z" |
    Where-Object -FilterScript  {($_.BaseName -match $MatchMask) -and ($_.BaseName -lt $LastBaseName)} |
    Remove-Item

}

