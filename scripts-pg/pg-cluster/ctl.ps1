
Import-Module pg-clusterctl-module -Force

$PSArgs = Get-PgPSArgs -ArgsArray $args
$Config = Get-Content -Path ($PSScriptRoot + '\config\config.json') | ConvertFrom-Json
$Clusters = Get-Content -Path ($PSScriptRoot + '\config\clusters.json') | ConvertFrom-Json 
$Log = New-Log -ScriptPath $PSCommandPath

if ($args[0] -eq 'wal') {

    $Log.Name = 'Backup-WAL'
    $Log.OutHost = $false
    Backup-PgaWal -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs

}
elseif ($args[0] -eq 'send-wal2ftp') {

    $FtpConfig = Get-Content -Path ($PSScriptRoot + '\config\ftp.json') | ConvertFrom-Json
    $FtpConn = Get-FtpConn -Srv $FtpConfig.srv -Usr $FtpConfig.usr -Pwd $FtpConfig.pwd -RootPath $FtpConfig.rootPath -IsSecure $FtpConfig.isSecure

    $Log.Name = 'Send-WAL2FTP'
    Send-PgaWal2Ftp -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn

}
elseif ($args[0] -eq 'clusters') {

    $Log.Name = 'Backup-Clusters'
    Backup-PgaClusters -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs

}
elseif ($args[0] -eq 'bases') {

    $Log.Name = 'Backup-Bases'
    Backup-PgaBases -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs

}
elseif ($args[0] -eq 'remove') {

    $FtpConfig = Get-Content -Path ($PSScriptRoot + '\config\ftp.json') | ConvertFrom-Json
    $FtpConn = Get-FtpConn -Srv $FtpConfig.srv -Usr $FtpConfig.usr -Pwd $FtpConfig.pwd -RootPath $FtpConfig.rootPath -IsSecure $FtpConfig.isSecure

    $Log.Name = 'Remove-BaseBackups'
    Remove-PgaBaseBackups -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn
    
    $Log.Name = 'Remove-ClusterBackups'
    Remove-PgaClusterBackups -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs -Ftp $FtpConn

}
else {
    Out-Log -Log $Log -Label Error -Text ('Error command: "' + $args[0] + '"') -InvokeThrow
}
