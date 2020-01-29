
Import-Module pg-clusterctl-module -Force

$PSArgs = Get-PgPSArgs -ArgsArray $args
$Config = Get-Content -Path ($PSScriptRoot + '\config\config.json') | ConvertFrom-Json
$Clusters = Get-Content -Path ($PSScriptRoot + '\config\clusters.json') | ConvertFrom-Json 
$Log = New-Log -ScriptPath $PSCommandPath

if ($args[0] -like 'backup-wal') {

    $Log.Name = 'Backup-WAL'
    $Log.OutHost = $false
    Backup-PgcWal -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs

}
elseif ($args[0] -like 'send-wal2ftp') {

    $FtpConfig = Get-Content -Path ($PSScriptRoot + '\config\ftp.json') | ConvertFrom-Json
    $FtpConn = Get-FtpConn -Srv $FtpConfig.srv -Usr $FtpConfig.usr -Pwd $FtpConfig.pwd -RootPath $FtpConfig.rootPath -IsSecure $FtpConfig.isSecure

    $Log.Name = 'Send-WAL2FTP'
    Send-PgcWal2Ftp -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn

}
elseif ($args[0] -like 'backup-clusters') {

    $Log.Name = 'Backup-Clusters'
    Backup-PgcClusters -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs

}
elseif ($args[0] -like 'backup-bases') {

    $Log.Name = 'Backup-Bases'
    Backup-PgcBases -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs

}
elseif ($args[0] -like 'remove-backups') {

    $FtpConfig = Get-Content -Path ($PSScriptRoot + '\config\ftp.json') | ConvertFrom-Json
    $FtpConn = Get-FtpConn -Srv $FtpConfig.srv -Usr $FtpConfig.usr -Pwd $FtpConfig.pwd -RootPath $FtpConfig.rootPath -IsSecure $FtpConfig.isSecure

    $Log.Name = 'Remove-BaseBackups'
    Remove-PgcBaseBackups -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn
    
    $Log.Name = 'Remove-ClusterBackups'
    Remove-PgcClusterBackups -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs -Ftp $FtpConn

}
elseif ($args[0] -like 'init-clusters') {

    $Log.Name = 'Init-Clustes'
    Initialize-PgcClusters -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs -Ftp $FtpConn

}
else {
    Out-Log -Log $Log -Label Error -Text ('Error command: "' + $args[0] + '"') -InvokeThrow
}
