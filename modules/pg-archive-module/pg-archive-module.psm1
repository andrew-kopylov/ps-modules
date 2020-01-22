
# EXPORT

function Backup-PgaClusters($Config, $Clusters, $Log, $PSArgs) {
    $LogLabel = 'Backup-Clusters'
    Out-Log -Log $Log -Label $LogLabel, Start
    foreach ($ClusterItem in $Clusters) {
        Backup-AuxCluster -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs
    }
    Out-Log -Log $Log -Label $LogLabel, End
}

function Backup-PgaWal($Config, $Clusters, $Log, $PSArgs) {

    #postgresql.conf parameters:
    #wal_level = replica
    #archive_mode = on
    #archive_command = 'powershell -f c:\\scripts\\carch.ps1 wal -p %p'
    #archive_timeout = 60

    #$args += '-p'
    #$args += 'pg_wal\00000001000000010000005D'

    #$PSArgs = @{
    #    p = 'pg_wal\00000001000000010000005D';
    #}

    $LogLabel = 'Backup-WAL'

    $DataDir = (Get-Location).Path
    $DataDirItem = Get-Item -Path $DataDir
    $ClusterCode = $DataDirItem.BaseName

    Out-Log -Log $Log -Label $LogLabel, Start -Text ('data ' + $DataDir + ', code ' + $ClusterCode)

    if ([String]::IsNullOrEmpty($PSArgs.p)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text 'Expected wal-file relative path parameter "p"' -InvokeThrow
    }

    # Relative wal-file path from data dir
    $WALRelPath = $PSArgs.p

    Out-Log -Log $Log -Label $LogLabel, WAL -Text $WALRelPath

    $BackupDir = Add-PgPath -Path $Config.sharebackup -AddPath clusters, $ClusterCode, wal

    # Source and destination WAL-file
    $WALFileName = (Add-PgPath -Path $DataDir -AddPath $WALRelPath)
    if (-not (Test-Path $WALFileName)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text 'Не найден исходный WAL-файл' -InvokeThrow
    }
    $WALItem = Get-Item -Path $WALFileName

    $WALDateTime = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $WALBackupDir = Add-PgPath -Path $BackupDir -AddPath ($WALDateTime + '-' + $WALItem.BaseName)
    Test-PgDir -Path $WALBackupDir -CreateIfNotExist | Out-Host
    $WALBackupFileName = Add-PgPath -Path $WALBackupDir -AddPath ($WALItem.Name)

    $WALBackupName = $ClusterCode + '-wal-' + $WALDateTime  + '-' + $WALItem.BaseName + '.7z'
    $WALBackupZip = Add-PgPath -Path $BackupDir -AddPath $WALBackupName

    Copy-Item -Path $WALFileName -Destination $WALBackupFileName -Force
    if (-not (Test-Path -Path $WALBackupFileName)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text 'Не найдена копия файла-WAL после копирования' -InvokeThrow
    }
    
    Compress-7zArchive -Path $WALBackupDir -DestinationPath $WALBackupZip -CompressionLevel Optimal -CompressionTreads 1 | Out-Null
    if (Test-Path -Path $WALBackupZip) {
        Remove-Item -Path $WALBackupDir -Force -Recurse 
        Out-Log -Log $Log -Label $LogLabel, End -Text ('WAL archive ' + $WALBackupZip)
    } 
    else {
        Out-Log -Log $Log -Label $LogLabel, Error -Text ('compress ' + $WALBackupDir) -InvokeThrow
    }
}

function Backup-PgaBases($Config, $Clusters, $Log, $PSArgs) {

    $LogLabel = 'Backup-Bases'

    Out-Log -Log $Log -Label $LogLabel, Start

    foreach ($ClusterItem in $Clusters) {
        Backup-AuxClusterBases -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs
    }

    Out-Log -Log $Log -Label $LogLabel, End
}

function Remove-PgaClusterBackups($Config, $Clusters, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Remove-ClusterBackups'

    Out-Log -Log $Log -Label $LogLabel, Start

    foreach ($ClusterItem in $Clusters) {
        Remove-AuxClusterFullBackups -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn
        Remove-AuxClusterWalBackups -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn
    }

    Out-Log -Log $Log -Label $LogLabel, End

}

function Remove-PgaBaseBackups($Config, $Clusters, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Remove-BaseBackups'

    Out-Log -Log $Log -Label $LogLabel, Start

    foreach ($ClusterItem in $Clusters) {
        Remove-AuxClusterBaseBackups -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn
    }

    Out-Log -Log $Log -Label $LogLabel, End

}

function Send-PgaWal2Ftp($Config, $Clusters, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Send-WAL2FTP'

    Out-Log -Log $Log -Label $LogLabel, Start

    foreach ($ClusterItem in $Clusters) {
        Send-AuxClusterWal2Ftp -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn
    }

    Out-Log -Log $Log -Label $LogLabel, End
}

# AUXILUARY

function Backup-AuxCluster($Config, $ClusterItem, $Log, $PSArgs) {

    $LogLabel = 'Backup-Cluster'
  
    Out-Log -Log $Log -Label $LogLabel, Start -Text ('code ' + $ClusterItem.code + ', port ' + $ClusterItem.port)
        
    $BackupDir = Add-PgPath -Path $Config.sharebackup -AddPath clusters, $ClusterItem.Code, data
    Test-PgDir -Path $BackupPath -CreateIfNotExist | Out-Null

    $BackupName = $ClusterItem.Code + '-cluster-' + (Get-Date).ToString('yyyyMMdd-HHmmss')
    $BackupPath = Add-PgPath -Path $BackupDir -AddPath $BackupName

    $Conn = Get-PgConn -Port $ClusterItem.Port

    Test-PgDir -Path $BackupPath -CreateIfNotExist | Out-Null
    $Result = Invoke-PgBasebackup -Conn $Conn -BackupPath $BackupPath -Format tar -XLogMethod fetch 
    if (-not $Result.OK) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text $Result.Error -InvokeThrow
    }
    Out-Log -Log $Log -Label $LogLabel, Done -Text ('time-taken ' + $Result.TimeSpan.ToString())

    $BackupPathZip = $BackupPath + '.7z'
    Out-Log -Log $Log -Label $LogLabel, Start-Compress
    $Result = Compress-7zArchive -Path $BackupPath -DestinationPath $BackupPathZip
    if (($Result.ExitCode -eq 0) -and (Test-Path -Path $BackupPathZip)) {
        Remove-Item -Path $BackupPath -Recurse -Force
    }
    else {
        Out-Log -Log $Log -Label $LogLabel, Error -Text ('Compress error, exit code ' + $Result.ExitCode) -InvokeThrow
    }
    Out-Log -Log $Log -Label $LogLabel, End-Compress
    Out-Log -Log $Log -Label $LogLabel, End
}

function Backup-AuxClusterBases($Config, $ClusterItem, $Log, $PSArgs) {

    $LogLabel = 'Backup-Bases'

    Out-Log -Log $Log -Label $LogLabel, Cluster-Start -Text ('code ' + $ClusterItem.Code + ', port ' + $ClusterItem.Port)

    $Conn = Get-PgConn -Port $ClusterItem.Port
    $DataBases = Get-PgDatabases -Conn $Conn

    $BackupClusterDir = Add-PgPath -Path $Config.sharebackup -AddPath bases, $ClusterItem.Code
    Test-PgDir -Path $BackupClusterDir -CreateIfNotExist | Out-Null

    foreach ($BaseItem in $DataBases) {
        
        if ($BaseItem.Name -like 'template0') {continue}
        if ($BaseItem.Name -like '*test') {continue}

        Out-Log -Log $Log -Label $LogLabel, Base-Start -Text $BaseItem.Name

        $BackupBaseDir = Add-PgPath -Path $BackupClusterDir -AddPath $BaseItem.Name
        Test-PgDir -Path $BackupBaseDir -CreateIfNotExist | Out-Null

        $BackupName = $BaseItem.Name + '_' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.backup'
        $BackupFile = Add-PgPath -Path $BackupBaseDir -AddPath $BackupName
        $Result = Invoke-PgDumpSimple -Conn $Conn -DbName $BaseItem.Name -File $BackupFile

        if ($Result.OK) {
            Out-Log -Log $Log -Label  $LogLabel, Base-Success -Text ('Time-taken ' + $Result.TimeSpan.ToString())
        }
        else {
            Out-Log -Log $Log -Label $LogLabel, Error -Text $Result.Error -InvokeThrow
        }
    }
  
    Out-Log -Log $Log -Label $LogLabel, Cluster-End
}

function Remove-AuxClusterFullBackups($Config, $ClusterItem, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Remove-ClusterFullBackups'
  
    Out-Log -Log $Log -Label $LogLabel, Start -Text ('code ' + $ClusterItem.code)
        
    $BackupDir = Add-PgPath -Path $Config.sharebackup -AddPath clusters, $ClusterItem.Code, data
    $FtpBackupDir = Join-FtpUrlPaths -Paths $Config.shareFtpBackup, clusters, $ClusterItem.Code, data

    # Patterns
    $BakPolicyTmpl = Get-BakPolicy -DatePattern '-yyyyMMdd-' -Prefix ($ClusterItem.Code + '-cluster-') -Postfix '.7z'

    # Store periods
    $BakPolicyTmpl = Get-BakPolicy  -Daily $Config.LocalDays -BakPolicy $BakPolicyTmpl

    # Local policy
    $BakPolicy = Get-BakPolicy  -Path $BackupDir -BakPolicy $BakPolicyTmpl

    # FTP policy
    $BakFtpPolicy = Get-BakPolicy  -Path $FtpBackupDir -BakPolicy $BakPolicyTmpl

    Invoke-BakSendToFtpAndRemoveOutdated -BakPolicyLocal $BakPolicy -FtpConn $FtpConn -BakPolicyFtp $BakFtpPolicy -Log $Log

    Out-Log -Log $Log -Label $LogLabel, End

}

function Remove-AuxClusterWalBackups($Config, $ClusterItem, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Remove-ClusterWALBackups'
  
    Out-Log -Log $Log -Label $LogLabel, Start -Text ('code ' + $ClusterItem.code)
        
    $BackupDir = Add-PgPath -Path $Config.sharebackup -AddPath clusters, $ClusterItem.Code, wal
    $FtpBackupDir = Join-FtpUrlPaths -Paths $Config.shareFtpBackup, clusters, $ClusterItem.Code, wal

    # Patterns
    $BakPolicyTmpl = Get-BakPolicy -DatePattern '-yyyyMMdd-' -Prefix ($ClusterItem.Code + '-wal-') -Postfix '.7z'

    # Store periods
    $BakPolicyTmpl = Get-BakPolicy  -Daily $Config.LocalDays -BakPolicy $BakPolicyTmpl

    # Local policy
    $BakPolicy = Get-BakPolicy  -Path $BackupDir -BakPolicy $BakPolicyTmpl

    # FTP policy
    $BakFtpPolicy = Get-BakPolicy  -Path $FtpBackupDir -BakPolicy $BakPolicyTmpl

    Invoke-BakSendToFtpAndRemoveOutdated -BakPolicyLocal $BakPolicy -FtpConn $FtpConn -BakPolicyFtp $BakFtpPolicy -Log $Log

    Out-Log -Log $Log -Label $LogLabel, End
}

function Remove-AuxClusterBaseBackups($Config, $ClusterItem, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Remove-ClusterBaseBackups'
  
    Out-Log -Log $Log -Label $LogLabel, Start -Text ('code ' + $ClusterItem.code)
        
    $BackupDir = Add-PgPath -Path $Config.sharebackup -AddPath bases, $ClusterItem.Code
    $FtpBackupDir = Join-FtpUrlPaths -Paths $Config.shareFtpBackup, bases, $ClusterItem.Code

    # Patterns
    $BakPolicyTmpl = Get-BakPolicy -DatePattern '_yyyyMMdd-' -Prefix '' -Postfix '.backup'

    # Store periods
    $BakPolicyTmplLocal = Get-BakPolicy  -Daily $Config.localDays -Weekly $Config.localWeeks -Monthly $Config.localMonths -Annual $Config.localYears -BakPolicy $BakPolicyTmpl
    $BakPolicyTmplFtp = Get-BakPolicy  -Daily $Config.ftpDays -Weekly $Config.ftpWeeks -Monthly $Config.ftpMonths -Annual $Config.ftpYears -BakPolicy $BakPolicyTmpl

    # Local policy
    $BakPolicy = Get-BakPolicy  -Path $BackupDir -BakPolicy $BakPolicyTmplLocal

    # FTP policy
    $BakFtpPolicy = Get-BakPolicy  -Path $FtpBackupDir -BakPolicy $BakPolicyTmplFtp

    Invoke-BakSendToFtpAndRemoveOutdated -BakPolicyLocal $BakPolicy -FtpConn $FtpConn -BakPolicyFtp $BakFtpPolicy -Log $Log -Recurse

    Out-Log -Log $Log -Label $LogLabel, End

}

function Send-AuxClusterWal2Ftp($Config, $ClusterItem, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Send-ClusterWAL2FTP'

    Out-Log -Log $Log -Label $LogLabel, Start -Text ('code ' + $ClusterItem.code)

    $BackupDir = Add-PgPath -Path $Config.sharebackup -AddPath clusters, $ClusterItem.Code, wal
    $FtpBackupDir = Join-FtpUrlPaths -Paths $Config.shareFtpBackup, clusters, $ClusterItem.Code, wal

    # Patterns
    $BakPolicyTmpl = Get-BakPolicy -DatePattern '-yyyyMMdd-' -Prefix ($ClusterItem.Code + '-wal-') -Postfix '.7z'

    Send-BakToFtp -BakPolicy $BakPolicyTmpl -LocalPath $BackupDir -FtpConn $FtpConn -FtpPath $FtpBackupDir -Log $Log | Out-Null

    Out-Log -Log $Log -Label $LogLabel, End
}

Export-ModuleMember -Function '*-Pga*'
