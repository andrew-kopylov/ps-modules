Import-Module 1c-module -Force
Import-Module 7z-module -Force

$PSScriptItem = Get-Item -Path $PSCommandPath

$ProcessName = $PSScriptItem.BaseName
$RepSharePath = 'D:\work\bases\update_by_cr'
$RepBackupDir = 'D:\cr-backups\cr'

$LogsDir = Add-1CPath -Path $PSScriptItem.DirectoryName -AddPath 'logs'
$Log = Get-1CLog -Dir $LogsDir -Name $PSScriptItem.BaseName
Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Begin' -LogText ($RepSharePath + ' -> ' + $RepBackupDir)

$Items = Get-ChildItem -Path $RepSharePath -Include '1cv8ddb.1cd' -File -Recurse

foreach ($DdbItem in $Items) {

    $RepPath = $DdbItem.DirectoryName
    $RepPathItem = Get-Item -Path $RepPath

    $RepPathDest = Add-1CPath -Path $RepBackupDir -AddPath $RepPathItem.BaseName
    $RepPathArch = Add-1CPath -Path $RepBackupDir -AddPath ($RepPathItem.BaseName + '_' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.7z')

    if (Test-Path -Path $RepPathDest) {
        Remove-Item -Path $RepPathDest -Force -Recurse
    }

    $Result = Backup-1CCR -Path $RepPath -BackupPath $RepPathDest -Log $Log
    if ($Result.OK) {
        $CmprRes = Compress-7zArchive -Path $RepPathDest -DestinationPath $RepPathArch
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Compress' -LogText ($RepPathDest + ' -> ' + $RepPathArch)
    }
    
    if (Test-Path -Path $RepPathDest) {
        Remove-Item -Path $RepPathDest -Force -Recurse
    }
    
}

Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText 'OK'
