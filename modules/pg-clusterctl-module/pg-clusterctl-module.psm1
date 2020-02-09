
# EXPORT

# PSArgs - hashtable with arguments setteld in format: "-c ClusterCode -b BaseName".

function Get-PgcPSArgs($ArgsArray) {

    # Reutrn Hashtable of arguments readed from $Args (array)

    $HArgs = @{}

    $ArgName = ''
    $PatternName = '^-(?<name>\w+)'

    foreach ($ArgValue in $ArgsArray) {
        if ($ArgValue -match $PatternName) {
            if (-not [string]::IsNullOrEmpty($ArgName)) {
                $HArgs[$ArgName] = $true
            }
            $ArgName = $Matches.name
        }
        elseif (-not [String]::IsNullOrEmpty($ArgName)) {
            if ($ArgValue -like '$true') {
                $HArgs[$ArgName] = $true
            }
            elseif ($ArgValue -like '$false') {
                $HArgs[$ArgName] = $false
            }
            else {
                $HArgs[$ArgName] = $ArgValue
            }
            $ArgName = ''
        }
    }

    if (-not [string]::IsNullOrEmpty($ArgName)) {
        $HArgs[$ArgName] = $true
    }

    $HArgs
}

function Add-PgcCluster($Config, $Clusters, $Log, $PSArgs) {

    $LogLabel = 'Add-Cluster'

    $code = $PSArgs.c
    $port = $PSArgs.p
    $pass = $PSArgs.pwd

    $ReturnClusters = $null
        
    if ([string]::IsNullOrEmpty($code) -or [string]::IsNullOrEmpty($port) -or [string]::IsNullOrEmpty($pass)) {
        $Msg = 'Mandatory parameters: -c <cluseter code> -p <cluster port> -pwd <app usr password>'
        Out-Log -Log $Log -Label $LogLabel, Error -Text $Msg
    }
    elseif (([PSCustomObject[]]$Clusters).Where({$_.code -like $code}).Count -gt 0) {
        $Msg = 'Cluster with code "' + $code + '" already exists.'
        Out-Log -Log $Log -Label $LogLabel, Error -Text $Msg        
    }
    elseif (([PSCustomObject[]]$Clusters).Where({$_.port -eq $port}).Count -gt 0) {
        $Msg = 'Cluster with port "' + $port + '" already exists.'
        Out-Log -Log $Log -Label $LogLabel, Error -Text $Msg
    }
    else {
        $ReturnClusters = @()
        $ReturnClusters += $Clusters
        $ReturnClusters += New-Object PSCustomObject -Property @{code = $code; port = $port; appUsrPwd = $pass}
        Out-Log -Log $Log -Text ('Added cluster code "' + $PSArgs.c + '" port "' + $PSArgs.p + '"')
    }
    
    $ReturnClusters
}

function Initialize-PgcClusters($Config, $Clusters, $Log, $PSArgs) {

    $WinUsr = [System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $Winusr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text 'Init-cluster needs administrator privileges.'
        break
    }

    $LogLabel = 'Init-Clusters'
    Out-Log -Log $Log -Label $LogLabel, Start
    foreach ($ClusterItem in $Clusters) {
        if (-not (Test-AuxCluster -Cluster $ClusterItem -PSArgs $PSArgs)) {continue}
        Init-AuxCluster -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs
    }
    Out-Log -Log $Log -Label $LogLabel, End
}

function Backup-PgcClusters($Config, $Clusters, $Log, $PSArgs) {
    $LogLabel = 'Backup-Clusters'
    Out-Log -Log $Log -Label $LogLabel, Start
    foreach ($ClusterItem in $Clusters) {
        if (-not (Test-AuxCluster -Cluster $ClusterItem -PSArgs $PSArgs)) {continue}
        Backup-AuxCluster -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs
    }
    Out-Log -Log $Log -Label $LogLabel, End
}

function Backup-PgcWal($Config, $Clusters, $Log, $PSArgs) {

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

function Backup-PgcBases($Config, $Clusters, $Log, $PSArgs) {

    $LogLabel = 'Backup-Bases'

    Out-Log -Log $Log -Label $LogLabel, Start

    foreach ($ClusterItem in $Clusters) {
        if (-not (Test-AuxCluster -Cluster $ClusterItem -PSArgs $PSArgs)) {continue}
        Backup-AuxClusterBases -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs
    }

    Out-Log -Log $Log -Label $LogLabel, End
}

function Remove-PgcClusterBackups($Config, $Clusters, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Remove-ClusterBackups'

    Out-Log -Log $Log -Label $LogLabel, Start

    foreach ($ClusterItem in $Clusters) {
        if (-not (Test-AuxCluster -Cluster $ClusterItem -PSArgs $PSArgs)) {continue}
        Remove-AuxClusterFullBackups -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn
        Remove-AuxClusterWalBackups -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn
    }

    Out-Log -Log $Log -Label $LogLabel, End

}

function Remove-PgcBaseBackups($Config, $Clusters, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Remove-BaseBackups'

    Out-Log -Log $Log -Label $LogLabel, Start

    foreach ($ClusterItem in $Clusters) {
        if (-not (Test-AuxCluster -Cluster $ClusterItem -PSArgs $PSArgs)) {continue}
        Remove-AuxClusterBaseBackups -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn
    }

    Out-Log -Log $Log -Label $LogLabel, End

}

function Send-PgcWal2Ftp($Config, $Clusters, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Send-WAL2FTP'

    Out-Log -Log $Log -Label $LogLabel, Start

    foreach ($ClusterItem in $Clusters) {
        if (-not (Test-AuxCluster -Cluster $ClusterItem -PSArgs $PSArgs)) {continue}
        Send-AuxClusterWal2Ftp -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs -FtpConn $FtpConn
    }

    Out-Log -Log $Log -Label $LogLabel, End
}

function Get-PgcBases($Config, $Clusters, $Log, $PSArgs) {

    $AllBases = @()

    foreach ($ClusterItem in $Clusters) {
        if (-not (Test-AuxCluster -Cluster $ClusterItem -PSArgs $PSArgs)) {continue}
        $ClusterBases = Get-AuxClusterBases -Config $Config -ClusterItem $ClusterItem -Log $Log -PSArgs $PSArgs
        $AllBases += $ClusterBases
    }

    $AllBases
}

# AUXILUARY

function Init-AuxCluster($Config, $ClusterItem, $Log, $PSArgs) {

    $LogLabel = 'Init-Cluster'
  
    $ClusterData = Add-PgPath -Path $Config.shareData -AddPath $ClusterItem.code
    $DefaultConf = Add-PgPath -Path $ClusterData -AddPath postgresql.conf

    if (Test-Path -Path $DefaultConf) {
        return
    }

    Out-Log -Log $Log -Label $LogLabel, Start -Text ('code ' + $ClusterItem.code + ', port ' + $ClusterItem.port)

    Test-PgDir -Path $ClusterData

    # Paths to config files.
    $ShareConfDir = Add-PgPath -Path $Config.shareData -AddPath conf.d
    $ShareConf = Add-PgPath -Path $ShareConfDir -AddPath share.conf
    $ClusterConf = Add-PgPath -Path $ShareConfDir -AddPath ($ClusterItem.code + '.conf')

    # Init cluster.
    Out-Log -Log $Log -Label $LogLabel, InitDb -Text ('pgdata: ' + $ClusterData)

    $Return = Invoke-PgInit -Auth trust -PgData $ClusterData -Encoding UTF8 -UserName postgres
    if (-not $Return.OK) {
        Out-Log -Log $Log -Label $LogLabel, InitDb-Error -Text $Return.Error -InvokeThrow
    }
    Out-Log -Log $Log -Label $LogLabel, InitDb-Success -Text $Return.Out

    # Create junction to share config directory.
    New-Item -Path (Add-PgPath -Path $ClusterData -AddPath conf.d) -ItemType Junction -Value $ShareConfDir | Out-Null

    # Include share and cluster configs to default config.
    ('') | Out-File -FilePath $DefaultConf -Append -Encoding ascii
    ('# INCLUDE SHARE AND CLUSTER CONFIGS') | Out-File -FilePath $DefaultConf -Append -Encoding ascii
    ('include = ''conf.d/share.conf''') | Out-File -FilePath $DefaultConf -Append -Encoding ascii
    ('include = ''conf.d/' + $ClusterItem.code + '.conf''') | Out-File -FilePath $DefaultConf -Append -Encoding ascii

    # Test/create local-trust pg_hba.conf (host-based-authentication.
    $LocalTrustHbaConf = Add-PgPath -Path $ShareConfDir -AddPath pg_hba-local-trust.conf
    if (-not (Test-Path -Path $LocalTrustHbaConf)) {
        '# TYPE DATABASE USER ADDRESS METHOD' | Out-File -FilePath $LocalTrustHbaConf -Encoding ascii
        'host all all 127.0.0.1/32 trust' | Out-File -FilePath $LocalTrustHbaConf -Encoding ascii -Append
        'host all all ::1/128 trust' | Out-File -FilePath $LocalTrustHbaConf -Encoding ascii -Append
    }

    # Create cluster config with customized port.
    ('port = ' + $ClusterItem.port + ' # Cluster port') | Out-File -FilePath $ClusterConf -Encoding ascii
    # Add trusted authentication.
    ('hba_file = ''' + $LocalTrustHbaConf.Replace('\', '/') + ''' # Cluster port') | Out-File -FilePath $ClusterConf -Encoding ascii -Append

    $Conn = Get-PgConn -Port $ClusterItem.port -Host localhost -PgData $ClusterData

    Out-Log -Log $Log -Label $LogLabel, Add-Roles

    # Start cluster to create users and passwords and stop it.
    $Return = Invoke-PgCtl -Command start -Conn $Conn
    if (-not $Return.OK) {
        Out-Log -Log $Log -Label $LogLabel, StartPG-Error -Text $Return.Error -InvokeThrow
    }
    Start-Sleep -Seconds 3 # start service
    if (-not [string]::IsNullOrEmpty($Config.postgresPwd)) {
        Invoke-PgSql -Conn $Conn -Command ('alter role postgres with password ''' + $Config.postgresPwd + '''')
    }
    if (-not [string]::IsNullOrEmpty($Config.appUsr)) {
        Invoke-PgSql -Conn $Conn -Command ('create role ' + $Config.appUsr + ' with superuser login password ''' + $ClusterItem.appUsrPwd + '''')
    }
    Invoke-PgCtl -Command stop -Conn $Conn

    Out-Log -Log $Log -Label $LogLabel, Create-Service

    # Create service
    Invoke-PgCtl -Command register -Conn $Conn -ServiceName ('pg-' + $ClusterItem.code) -ServiceUsr $Config.serviceUsr -ServicePwd $Config.servicePwd

    # Create cluster config with customized port.
    ('port = ' + $ClusterItem.port + ' # Cluster port') | Out-File -FilePath $ClusterConf -Encoding ascii

    # Set owner to new files
    if (-not [string]::IsNullOrEmpty($Config.serviceUsr)) {
        Out-Log -Log $Log -Label $LogLabel, Set-DataOwner
        icacls "$ClusterData" /setowner "$Config.serviceUsr" /T
        icacls "$ClusterConf" /setowner "$Config.serviceUsr" /T
    }

    Out-Log -Log $Log -Label $LogLabel, Start-Service

    # Start pg-service
    Start-Service -Name ('pg-' + $ClusterItem.code)
        
    Out-Log -Log $Log -Label $LogLabel, End
}

function Backup-AuxCluster($Config, $ClusterItem, $Log, $PSArgs) {

    $LogLabel = 'Backup-Cluster'

    if (-not(Test-AuxClusterDataExists -Config $Config -Cluster $ClusterItem)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text ('Cluster not initialized: code ' + $ClusterItem.code)
        return
    }
  
    Out-Log -Log $Log -Label $LogLabel, Start -Text ('code ' + $ClusterItem.code + ', port ' + $ClusterItem.port)
        
    $BackupDir = Add-PgPath -Path $Config.sharebackup -AddPath clusters, $ClusterItem.Code, data
    Test-PgDir -Path $BackupPath -CreateIfNotExist | Out-Null

    $BackupName = $ClusterItem.Code + '-cluster-' + (Get-Date).ToString('yyyyMMdd-HHmmss')
    $BackupPath = Add-PgPath -Path $BackupDir -AddPath $BackupName

    Test-PgDir -Path $BackupPath -CreateIfNotExist | Out-Null

    $Conn = Get-AuxPgConn -ClusterItem $ClusterItem -PSArgs $PSArgs
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

    Out-Log -Log $Log -Label $LogLabel, Cluster -Text ('code ' + $ClusterItem.Code + ', port ' + $ClusterItem.Port)

    if (-not(Test-AuxClusterDataExists -Config $Config -Cluster $ClusterItem)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text ('Cluster not initialized: code ' + $ClusterItem.code)
        return
    }

    if ($PSArgs.IncludePostgresBase -eq $null) {
        $PSArgs.IncludePostgresBase = $true
    }
    
    if ($PSArgs.IncludeTemplateBases -eq $null) {
        $PSArgs.IncludeTemplateBases = $true
    }

    if ($PSArgs.ExcludeTestBases -eq $null) {
        $PSArgs.ExcludeTestBases = $true
    }

    $Databases = Get-AuxClusterBases -Config $Config -ClusterItem $ClusterItem -PSArgs $PSArgs -Log $Log

    $BackupClusterDir = Add-PgPath -Path $Config.sharebackup -AddPath bases, $ClusterItem.Code
    Test-PgDir -Path $BackupClusterDir -CreateIfNotExist | Out-Null

    foreach ($BaseItem in $DataBases) {
        
        Out-Log -Log $Log -Label $LogLabel, Base-Start -Text $BaseItem.Name

        $BackupBaseDir = Add-PgPath -Path $BackupClusterDir -AddPath $BaseItem.Name
        Test-PgDir -Path $BackupBaseDir -CreateIfNotExist | Out-Null

        $BackupName = $BaseItem.Name + '_' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.backup'
        $BackupFile = Add-PgPath -Path $BackupBaseDir -AddPath $BackupName

        $Conn = Get-AuxPgConn -ClusterItem $ClusterItem -PSArgs $PSArgs
        $Result = Invoke-PgDumpSimple -Conn $Conn -DbName $BaseItem.Name -File $BackupFile

        if ($Result.OK) {
            Out-Log -Log $Log -Label  $LogLabel, Base-Success -Text ('Time-taken ' + $Result.TimeSpan.ToString())
        }
        else {
            Out-Log -Log $Log -Label $LogLabel, Error -Text $Result.Error -InvokeThrow
        }
    }
  
    Out-Log -Log $Log -Label $LogLabel, Cluster -Text 'End'
}

function Remove-AuxClusterFullBackups($Config, $ClusterItem, $Log, $PSArgs, $FtpConn) {

    $LogLabel = 'Remove-ClusterFullBackups'

    if (-not(Test-AuxClusterDataExists -Config $Config -Cluster $ClusterItem)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text ('Cluster not initialized: code ' + $ClusterItem.code)
        return
    }
  
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

    if (-not(Test-AuxClusterDataExists -Config $Config -Cluster $ClusterItem)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text ('Cluster not initialized: code ' + $ClusterItem.code)
        return
    }
  
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

    if (-not(Test-AuxClusterDataExists -Config $Config -Cluster $ClusterItem)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text ('Cluster not initialized: code ' + $ClusterItem.code)
        return
    }
  
    Out-Log -Log $Log -Label $LogLabel, Start -Text ('code ' + $ClusterItem.code)
        
    $BackupDir = Add-PgPath -Path $Config.sharebackup -AddPath bases, $ClusterItem.Code
    $FtpBackupDir = Join-FtpUrlPaths -Paths $Config.shareFtpBackup, bases, $ClusterItem.Code

    $BaseName = ''
    if ($PSArgs -ne $null) {
        $BaseName = [string]$PSArgs.b
    }

    # Patterns
    $BakPolicyTmpl = Get-BakPolicy -DatePattern ($BaseName + '_yyyyMMdd-') -Prefix '' -Postfix '.backup'

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

    if (-not(Test-AuxClusterDataExists -Config $Config -Cluster $ClusterItem)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text ('Cluster not initialized: code ' + $ClusterItem.code)
        return
    }

    Out-Log -Log $Log -Label $LogLabel, Start -Text ('code ' + $ClusterItem.code)

    $BackupDir = Add-PgPath -Path $Config.sharebackup -AddPath clusters, $ClusterItem.Code, wal
    $FtpBackupDir = Join-FtpUrlPaths -Paths $Config.shareFtpBackup, clusters, $ClusterItem.Code, wal

    # Patterns
    $BakPolicyTmpl = Get-BakPolicy -DatePattern '-yyyyMMdd-' -Prefix ($ClusterItem.Code + '-wal-') -Postfix '.7z'

    Send-BakToFtp -BakPolicy $BakPolicyTmpl -LocalPath $BackupDir -FtpConn $FtpConn -FtpPath $FtpBackupDir -Log $Log | Out-Null

    Out-Log -Log $Log -Label $LogLabel, End
}

function Get-AuxClusterBases($Config, $ClusterItem, $Log, $PSArgs) {

    $LogLabel = 'Get-ClusterBases'

    if (-not(Test-AuxClusterDataExists -Config $Config -Cluster $ClusterItem)) {
        Out-Log -Log $Log -Label $LogLabel, Error -Text ('Cluster not initialized: code ' + $ClusterItem.code)
        return
    }

    $Bases = @()
    
    $Conn = Get-AuxPgConn -ClusterItem $ClusterItem -PSArgs $PSArgs
    $Databases = Get-PgDatabases -Conn $Conn
    foreach ($BaseItem in $Databases) {

        $BaseTest = Test-AuxBase -Base $BaseItem -PSArgs $PSArgs
        if (-not $BaseTest) {continue}

        $ClusterBase = @{
            oid = $BaseItem.oid;
            name = $BaseItem.name;
            cluster = $ClusterItem.code;
        }

        $Bases += New-Object PSCustomObject -Property $ClusterBase
    }

    $Bases
}

function Get-AuxPgConn($ClusterItem, $PSArgs) {
    Get-PgConn -Port $ClusterItem.Port
}

function Test-AuxCluster($Cluster, $PSArgs) {
    $Test = $true
    if ($PSArgs -ne $null) {
        if (-not [string]::IsNullOrEmpty($PSArgs.c)) {
            $ClusterCode = ''
            if ($Cluster -is [string]) {
                $ClusterCode = $Cluster
            }
            else {
                $ClusterCode = $Cluster.code
            }
            $Test = ($ClusterCode -like $PSArgs.c)
        }       
    }
    $Test
}

function Test-AuxBase($Base, $PSArgs) {

    $Test = $true

    $BaseName = ''
    if ($Base -is [string]) {
        $BaseName = $Base
    }
    else {
        $BaseName = $Base.Name
    }

    if (-not $PSArgs.IncludePostgresBase) {
        if ($BaseName -like 'postgres') {$Test = $false}
    }

    if (-not $PSArgs.IncludeTemplate0Base) {
        if ($BaseName -like 'template0') {$Test = $false}
    }

    if (-not $PSArgs.IncludeTemplateBases) {
        if ($BaseName -like 'template*') {$Test = $false}
    }

    if ($BSArgs.ExcludeTestBases) {
        if ($BaseName -like '*test') {$Test = $false}
    }

    if ($PSArgs -ne $null) {
        if (-not [string]::IsNullOrEmpty($PSArgs.b)) {
            $Test = ($BaseName -like $PSArgs.b)
        }       
    }

    $Test
}

function Test-AuxClusterDataExists($Config, $Cluster) {
    $DefaultConf = Add-PgPath -Path $Config.shareData -AddPath $ClusterItem.code, postgresql.conf
    Test-Path -Path $DefaultConf
}

Export-ModuleMember -Function '*-Pgc*'
