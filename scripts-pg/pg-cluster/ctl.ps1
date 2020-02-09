
Import-Module pg-clusterctl-module -Force

$ConfigFile = $PSScriptRoot + '\config\config.json'
$ClustersFile = $PSScriptRoot + '\config\clusters.json'

$PSArgs = Get-PgcPSArgs -ArgsArray $args
$Config = Get-Content -Path $ConfigFile | ConvertFrom-Json
$Clusters = Get-Content -Path $ClustersFile | ConvertFrom-Json 
$Log = New-Log -ScriptPath $PSCommandPath

if ($PSArgs.RunAsAdministrator) {
    $WinUsr = [System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $Winusr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $ArgsString = [string]::Join(' ', $args)
        Start-Process -FilePath 'powershell' -ArgumentList ('-f "' + $PSCommandPath + '" ' + $ArgsString) -Verb RunAs
        break
    }
}

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
elseif ($args[0] -like 'get-config') {

    $Config | Out-Host

}
elseif ($args[0] -like 'get-clusters') {

    $Clusters | Out-Host

}
elseif ($args[0] -like 'get-bases') {
    
    $Log.Name = 'Get-Bases'
    $Bases = Get-PgcBases -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs
    $Bases | Out-Host

}
elseif ($args[0] -like 'add-cluster') {
    
    $Log.Name = 'Add-Cluster'

    $NewClusters = Add-PgcCluster -Config $Config -Clusters $Clusters -Log $Log -PSArgs $PSArgs
    if ($NewClusters -ne $null) {
        $NewClusters | ConvertTo-Json | Out-File -FilePath $ClustersFile
        if ($PSArgs.InitCluster) {
            Initialize-PgcClusters -Config $Config -Clusters $NewClusters -Log $Log -PSArgs $PSArgs
        }
    }

}
elseif ($args[0] -like 'help') {

$helptext = '
NAME:
    
    pg-control\ctl - control PostgreSQL cluster.

SYNAPSIS:

    .\ctl command [options]

COMMANDS:
    
    - backup-bases [-c clustercode] [-b basename] - backup all bases, or
        only cluster with parameter -c, or only base with parameter -b.

    - backup-clusters [-c clustercode] - backup all custers, or 
        only cluster with parameter -c.
    
    - remove-backups [-c clustercode] - remove all outdated backups local and stored (ftp, ...), or
        only cluster with parameter -c.
        Before remove local files they are storing (ftp, ...).
        Local backups remove if they are stored (ftp, ...).

    - add-cluster -c clustercode -p clusterport -pwd appUsrPasword [-InitCluster [$true|$false]] -
        add cluster description in clusters-conifg-file.
        InitClsuter flag invoke clusterInitialization (see init-clusters command), need admin privileges.

    - init-clusters [-c clustercode] - initialize new clusters from clusters-config-file:
        invoke initdb, create cluster *.conf files, create and run service.
        If cluster is initialized before, it is skipped.
        Need admin privileges.
    
    - send-wal2ftp [-c clustercode] - send archived WAL files to ftp storage.
    
    - backup-wal -p %p - used in "archive_command" postgresql.conf parameter.

    - get-config - return list of config parameters.

    - get-clusters - return list of clusters in clusters-config-file.

    - get-bases [-c clustercode] [-b basename] [-IncludePostgresBase [$true|$false]] [-IncludeTemplateBases [$true|$false]] [-ExcludeTestBases [$true|$false]]
        return list of cluster bases.
        IncludePostgresBase, IncludeTemplateBases, ExcludeTestBases - default off.

OPTIONS:

    - RunAsAdministrator - start process with administrator privileges.


EXAMPLES:
    
    Set current directory to ...\pg-cluster
    
        cd c:\scripts\pg-cluster
    
    Backup base postgres from all clusters
    
        .\ctl backup-bases -b postgres
    
    Backup all bases from cluster with code "mycltr"
        
        .\ctl backup-bases -c mycltr

    Backup base "mybase" from cluster with code "mycltr"
        
        .\ctl backup-bases -c mycltr -b mybase

USED MODULES:
    - pg-clusterctl-module
    - pg-module
    - backup-module
    - log-module
    - ftp-module
    - 7z-module
'

    $helptext | Out-Host

}
else {

    $Msg = 'Bad command: "' + $args[0] + '". Use "help" command.'
    $Msg | Out-Host

    Out-Log -Log $Log -Label Error -Text $Msg -OutHost $false

}
