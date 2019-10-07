# PostgreSQL: version 1.0

function Invoke-PgBackup($ConnParams, $BackupDir, $Period = "", [int]$StorePeriods = 0) {

    # Period: d - day (default), w - week, m - month, y - year
    
    $DbName = $ConnParams.DbName;
    $BackupDate = (Get-Date).ToString('yyyyMMdd_HHmmss')

    $BackupName = $DbName + '_' + $BackupDate;

    if ($StorePeriods -gt 0) {
        if ($Period -eq '') {$Period = 'd'} # day by default
        $FindedBackups = Find-PgBackup -DbName $DbName -BackupDir $BackupDir -Period $Period -StorePeriods $StorePeriods
        if ($FindedBackups.Count -gt 0) {
            Return ''
        };
        $BackupName = $BackupName + '_' + $Period + $StorePeriods.ToString()
    }

    $BackupFile = $BackupDir + '\' + $BackupName + '.' + (Get-PgBackupExtention)

    $PgArgs = '';
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'host' -Value $ConnParams.Srvr
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'port' -Value $ConnParams.Port

    # Addition parameters.
    $PgArgs = $PgArgs + ' --no-password --format=custom --encoding=UTF8'
    
    # Database and Backup file.
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'file' -Value $BackupFile
    $PgArgs = $PgArgs + ' ' + $DbName

    $PgArgs = $PgArgs.Trim()
    $PgArgs
    Start-Process -FilePath "pg_dump" -ArgumentList $PgArgs -NoNewWindow -Wait

    Return $BackupFile
}

function Invoke-PgSql($ConnParams, $Sql) {

    $PgArgs = "";

    $PgArgs = Add-PgArg -Args $PgArgs -Name 'dbname' -Value $ConnParams.DbName -DefValue 'postgres'
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'username' -Value $ConnParams.Usr
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'host' -Value $ConnParams.Srvr
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'port' -Value $ConnParams.Port

    # Addition parameters.
    $PgArgs = $PgArgs + ' --no-password'
    
    $PgArgs = $PgArgs.Trim()
    $Return = Start-Process -FilePath "psql" -ArgumentList $PgArgs -NoNewWindow -Wait

    $Return
}

function Get-PgDatabases($ConnParams) {




}

function Invoke-PgReindex($DbName, $TabName) {

}


function Get-PgBackupExtention() {
    'backup'
}

function Get-PgConnParams($DbName = $null, $Usr = $null, $Srvr = $null, $Port = $null) {
    @{DbName = $DbName; Usr = $Usr; Srvr = $Srvr; Port = $Port}
}

function Add-PgArg($Args, $Name, $Value, $DefValue) {
    if ($Value -ne $null) {
        $Args = $Args + ' --' + $Name + '=' + $Value
    }
    elseif ($DefValue -ne $null) {
        $Args = $Args + ' --' + $Name + '=' + $DefValue
    }
    $Args
} 


