Import-Module pg-module -Force
#Import-Module backup-module -Force

$PSScriptItem = Get-Item -Path $PSCommandPath

$ConfigDir = $PSScriptItem.DirectoryName + '\config'

$Clusters = Get-Content -Path ($ConfigDir + '\clusters.json') | ConvertFrom-Json
$Config = Get-Content -Path ($ConfigDir + '\config.json') | ConvertFrom-Json

#$BakPolicy = Get-BakPolicy -Path $Config.sharebackup -Postfix '.backup' -DatePattern 'yyyyMMdd' -Daily 30 -Weekly 8 -Monthly 12 -Annual 2
#Remove-BakFiles -BakPolicy $BakPolicy -Recurse

foreach ($ClusterItem in $Clusters) {

    $Conn = Get-PgConn -Port $ClusterItem.Port
    $DataBases = Get-PgDatabases -Conn $Conn

    $BackupClusterDir = $Config.sharebackup + '\' + $ClusterItem.Code
    if (-not (Test-Path -Path $BackupClusterDir)) {
        New-Item -Path $BackupClusterDir -ItemType Directory -Force | Out-Null
    }

    foreach ($BaseItem in $DataBases) {
        
        if ($BaseItem.Name -like 'template0') {continue}
        if ($BaseItem.Name -like '*test') {continue}

        $BackupBaseDir = $BackupClusterDir + '\' + $BaseItem.Name
        if (-not (Test-Path -Path $BackupBaseDir)) {
            New-Item -Path $BackupBaseDir -ItemType Directory -Force | Out-Null
        }

        $BackupFile = $BackupBaseDir + '\' + $BaseItem.Name + '_' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.backup'
        Invoke-PgDumpSimple -Conn $Conn -DbName $BaseItem.Name -File $BackupFile
    }

}