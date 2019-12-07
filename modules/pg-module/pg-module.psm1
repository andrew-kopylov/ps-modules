
# PostgreSQL: version 1.1

function Invoke-PgBackup($Conn, $BackupDir, $Period = "", [int]$StorePeriods = 0) {

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

    Invoke-PgDumpSimple -Conn $Conn -File $BackupFile -Compress 9
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

function Get-PgDatabases() {


    




}

function Invoke-PgReindex($DbName, $TabName) {

}

# Low level functions

function Get-PgConn {
    param (
        $Bin,
        $PgData,
        $DbName,
        $Host,
        $Port,
        $UserName,
        $NoPassword,
        $Password,
        $StatusInterval,
        [switch]$Verbose
    )
    [ordered]@{
        dbname = $DbName;
        host = $Host;
        port = $Post;
        username = $UserName;
        nopassword = $NoPassword;
        password = $Password;
        statusInterval = $StatusInterval;
        verbose = $Verbose
    }
}

function Invoke-PgBasebackup {
    param (
        $Conn,
        [Parameter(Mandatory=$true)]
        [ValidateSet('plain', 'tar')]
        $Format,
        $MaxRate,
        $WriteRecoveryConf,
        $Slot,
        $TablespaceMapping,
        $XLogDir,
        [switch]$XLog,
        [ValidateSet('fetch', 'stream')]
        $XLogMethod,
        [switch]$GZip,
        $Compress,
        [ValidateSet('fast', 'spread')]
        $Checkpoint,
        $Lable,
        [switch]$Progress,
        [switch]$Verb
    )

    $ArgStr = ''

    $ArgList1 = [ordered]@{
        D = $Conn.PgData;
        F = $Format;
        r = $MaxRate;
        S = $Slot;
        T = $TablespaceMapping;
        X = $XLogMethod;
        z = $GZip;

    }
    $ArgStr = Get-PgArgs -ArgStr $ArgStr -ArgList $ArgList1

    $ArgList2 = [ordered]@{
        R = $WriteRecoveryConf;
        x = $XLog;
        Z = $Compress;
        c = $Checkpoint;
        l = $Lable;

    }
    $ArgStr = Get-PgArgs -ArgStr $ArgStr -ArgList $ArgList2
    $ArgStr = Add-PgArg  -ArgStr $ArgStr -Name 'xlogdir' -ArgEnter '--' -ValueSep '='

    $ArgList3 = [ordered]@{
        P = $Progress;
        v = ($Conn.verb -or $Verb);
    }
    $ArgStr = Get-PgArgs -ArgStr $ArgStr -ArgList $ArgList3

    $ArgList4 = [ordered]@{
        d = $Conn.dbname;
        h = $Conn.host;
        p = $Conn.port;
        s = $Conn.statusInterval;
        U = $Conn.username;
        w = $Conn.nopassword;
    }
    $ArgStr = Get-PgArgs -ArgStr $ArgStr -ArgList $ArgList4

    $ArgList5 = [ordered]@{
        W = $Conn.password;
    }
    $ArgStr = Get-PgArgs -ArgStr $ArgStr -ArgList $ArgList5

    Invoke-PgExec -Conn $Conn -ExecName 'pg_basebackup' -ArgStr $ArgStr
}

function Invoke-PgDumpSimple {
    param (
        $Conn,
        $File,
        $Compress
    )

    # Never prompt for password
    $Conn.nopassword = $true

    Invoke-PgDump -Conn $Conn -File $File -Format custom -JobsNum $JobsNum -Compress $Compress -Encoding 'UTF8'
}

function Invoke-PgDump {
    param(
        $Conn,
        [Parameter(HelpMessage="Output file or directory name.")]
        $File,
        [Parameter(HelpMessage="Output file format.")]
        [ValidateSet('custom', 'direcotry', 'tar', 'plain_text')]
        $Format,
        [Parameter(HelpMessage="Use this many parallel jobs to dump.")]
        $JobsNum,
        [Parameter(HelpMessage="Compression level for compressed formats (0-9).")]
        $Compress,
        [Parameter(HelpMessage="Fail after waiting TIMEOUT for a table lock.")]
        $LockWaitTimeout,
        [Parameter(HelpMessage="Do not wait for changes to be written safely to disk.")]
        [switch]$NoSync,
        [switch]$DataOnly,
        [switch]$Blobs,
        [switch]$NoBlobs,
        [Parameter(HelpMessage="Clean (drop) database objects before recreating.")]
        [switch]$Clean,
        [Parameter(HelpMessage="Include commands to create database in dump.")]
        [switch]$CreateDbCmd,
        $Encoding,
        $Schema,
        $ExcludeSchema,
        [switch]$Oids,
        [switch]$NoOwner,
        [switch]$SchemaOnly,
        $SuperUser,
        $Tables,
        $ExcludeTables,
        [switch]$NoPrivileges,
        [switch]$BinaryUpdate,
        [switch]$ColumnInserts,
        [switch]$DisableDollarQuoting,
        [switch]$DisableTriggers,
        [switch]$EnableRowSecurity,
        $ExcludeTablesData,
        [switch]$IfExists,
        [switch]$Inserts,
        [switch]$NoPublications,
        [switch]$NoSecurityLables,
        [switch]$NoSubscriptions,
        [switch]$NoSyncronizedSnapshots,
        [switch]$NoTablesSpaces,
        [switch]$NoUnloggedTableData,
        [switch]$QuoteAllIdentifiers,
        $Section,
        $SerializableDeferrable,
        $Snapshot,
        [switch]$StrictNames,
        [switch]$UseSetSessionAuth,
        $Role
    )

    $ArgList = [ordered]@{
        file = $File;
        format = $Format;
        jobs = $JobsNum;
        verbose = $Conn.Verbose;
        compress = $Compress;
        lock_wait_timeout = $LockWaitTimeout;
        no_sync = $NoSync;
        data_only = $DataOnly;
        blobs = $Blobs;
        no_blobs = $NoBlobs;
        clean = $Clean;
        create = $CreateDbCmd;
        encoding = $Encoding;
        schema = $Schema;
        exclude_schema = $ExcludeSchema;
        oids = $Oids;
        no_owner = $NoOwner;
        schema_only = $SchemaOnly;
        superuser = $SuperUser;
        table = $Tables;
        exclude_table = $ExcludeTables;
        no_privileges = $NoPrivileges;
        binary_upgrade = $BinaryUpdate;
        column_inserts = $ColumnInserts;
        disable_dollar_quoting = $DisableDollarQuoting;
        disable_triggers = $DisableTriggers;
        enable_row_security = $EnableRowSecurity;
        exclude_table_data = $ExcludeTablesData;
        if_exists = $IfExists;
        inserts = $Inserts;
        no_publications = $NoPublications;
        no_security_labels = $NoSecurityLables;
        no_subscriptions = $NoSubscriptions;
        no_synchronized_snapshots = $NoSyncronizedSnapshots;
        no_tablespaces = $NoTablesSpaces;
        no_unlogged_table_data = $NoUnloggedTableData;
        quote_all_identifiers = $QuoteAllIdentifiers;
        section = $Section;
        serializable_deferrable = $SerializableDeferrable;
        snapshot = $Snapshot;
        strict_names = $StrictNames;
        use_set_session_authorization = $UseSetSessionAuth;
        dbname = $Conn.DbName;
        host = $Conn.Host;
        port = $Conn.Port;
        username = $Conn.UserName;
        no_password = $Conn.NoPassword;
        password = $Conn.Password;
        role = $Role
    }

    $AgrsStr = Get-PgArgs -ArgList $ArgList -ArgEnter '--' -ValueSep '='
    Invoke-PgExec -Conn $Conn -ExecName 'pg_dump' -ArgStr $AgrsStr    
}

function Invoke-PgRestore {

    # TODO: create function

}

function Invoke-PgCtl {
    param (
        [ValidateSet('initdb', 'start', 'stop', 'restart', 'reload', 'status', 'promote', 'kill', 'register', 'unregister')]
        $Command,
        $Conn,
        $PgData,
        $Silent,
        $Timeout,
        [switch]$Wait,
        [switch]$NoWait,
        [ValidateSet('smart', 'fast', 'immediate')]
        $Mode,
        $LogFile,
        $Options,
        $ServiceName,
        $ServiceUsr,
        $ServicePwd,
        [ValidateSet('auto', 'demand')]
        $ServiceStartType,
        $EventSource
    )

    if ([string]::IsNullOrEmpty($PgData)) {
        $PgData = $Conn.PgData
    }

    $ArgStr = $Command

    $ArgList1 = [ordered]@{
        pgdata = $PgData;
        silent = $Silent;
        timeout = $Timeout;
        wait = $Wait;
        no_wait = $NoWait;
        log = $LogFile;
        options = $Options;
        mode = $Mode;
    }

    $ArgStr = Get-PgArgs -ArgList $ArgList1 -ArgStr $ArgStr -ArgEnter '--' -ValueSep '='

    $ArgList2 = [ordered]@{
        N = $ServiceName;
        P = $ServicePwd;
        U = $ServiceUsr;
        S = $ServiceStartType;
        e = $EventSource;
    }

    $ArgStr = Get-PgArgs -ArgList $ArgList2 -ArgStr $ArgStr

    Invoke-PgExec -Conn $Conn -ExecName 'pg_ctl' -ArgStr $ArgStr
}

function Invoke-PgExec($Conn, $ExecName, $ArgStr) {
    $FilePath = Add-PgPath -Path (Get-PgBin -Conn $Conn) -AddPath $ExecName 
    $InvokeError = @()
    $Result = Invoke-Expression ($FilePath + ' ' + $ArgStr) -ErrorVariable InvokeError
    @{Result = $Result; Error = $InvokeError[0]}
}

function Get-PgBin($Conn) {
    $Conn.bin
}

####
# LOGGING
####

# Return log parameters
function Get-PgLog($Dir, $Name, $OutHost) {
    # Log directory, Log file base name, Out host - bool, log to Out-Host
    @{Dir = $Dir; Name = $Name; OutHost = $OutHost}
}

function Out-PgLog($Log, $Mark, $Text, $OutHost, [switch]$InvokeThrow) {

    $LogDir = ''
    $LogName = ''

    if ($Log -ne $null) {
        $LogDir = $Log.Dir
        $LogName = $LogName.Name
    }

    if ([String]::IsNullOrEmpty($LogDir)) {
        $LogDir = Get-PgDefaultLogDir
    }
    Test-PgDir -Path $LogDir -CreateIfNotExist | Out-Null

    $LogName = $Log.Name;
    if ([String]::IsNullOrEmpty($LogName)) {
        $LogName = "pg-module";
    }

    $LogFile = Add-PgPath -Path $LogDir -AddPath ((Get-Date).ToString('yyyyMMdd') + '-' + $LogName + '.log')
    $OutLogText = Get-PgLogText -LogName $LogName -LogMark $Mark -LogText $Text

    $OutLogText | Out-File -FilePath $LogFile -Append

    if ($OutHost -or (($OutHost -ne $false) -and $Log.OutHost) -or (($OutHost -eq $null) -and ($Log.OutHost -eq $null))) {
        $OutLogText | Out-Host
    }

    if ($InvokeThrow) {
        throw $OutLogText
    }

}

function Get-PgLogText($LogName, $LogMark, $LogText) {
    if ([String]::IsNullOrEmpty($LogText)) {return ''}
    $FullLogText = (Get-Date).ToString('yyyy.MM.dd HH:mm:ss');
    $FullLogText = Add-PgString -Str $FullLogText -Add $LogName -Sep ' ';
    $FullLogText = Add-PgString -Str $FullLogText -Add $LogMark -Sep '.';
    $FullLogText = Add-PgString -Str $FullLogText -Add $LogText -Sep ': ';
    $FullLogText
}

function Get-PgDefaultLogDir() {
    $LogDir = ''
    if (-not [String]::IsNullOrEmpty($env:TEMP)) {$LogDir = $env:TEMP}
    else {$LogDir = $env:TMP}
    $LogDir = Add-PgPath -Path $LogDir -AddPath 'pg-module'
    $LogDir
}


####
# AUXILIARY FUNC
####

function Get-PgPathParent($Path) {
    $Info = [System.IO.DirectoryInfo]::new($Path)
    $Info.Parent.FullName
}

function Get-PgPathBaseName($Path) {
    $Info = [System.IO.DirectoryInfo]::new($Path)
    $Info.BaseName
}

function Get-PgPSArgs($ArgsArray) {

    # Reutrn Hashtable of arguments readed from $Args (array)

    $HArgs = @{}

    $ArgName = ''
    $PatternName = '^-(?<name>\w+)'

    foreach ($ArgValue in $ArgsArray) {
        if ($ArgValue -match $PatternName) {
            $ArgName = $Matches.name
        }
        elseif (-not [String]::IsNullOrEmpty($ArgName)) {
            $HArgs[$ArgName] = $ArgValue
            $ArgName = ''
        }
    }

    $HArgs
}

function Get-PgArgs($ArgList, $ArgStr = '', $ArgSep = ' ', $ArgEnter = '-', $ValueSep = ' ') {
    foreach ($ArgKey in $ArgList.Keys) {
        $ArgStr = Add-PgArg -ArgStr $ArgStr -Name $ArgKey -Value ($ArgList.$ArgKey) -ArgSep $ArgSep -ArgEnter $ArgEnter -ValueSep $ValueSep
    }
    $ArgStr
}

function Add-PgArg($ArgStr, $Name, $Value, $DefaultValue,  $ArgSep = ' ', $ArgEnter = '-', $ValueSep = ' ') {
    
    if ($Value -eq $null) {$Value = $DefaultValue}
    if ($Value -eq $null) {return $ArgStr}

    $Name = $Name.Replace('_', '-')

    $CurArg = ''
    if (($Value -is [bool]) -or ($Value -is [switch]) -or ($Value -eq $true) -or ($Value -eq $false)) {
        if ($Value) {
            $CurArg = $ArgEnter + $Name
        }
    }
    elseif ($Value -is [System.Array]) {
        foreach ($ArrayValueItem in $Value) {
            $CurArg = Add-PgArg -ArgStr $CurArg -Name $Name -Value $ArrayValueItem -DefaultValue $DefaultValue -ArgSep $ArgSep -ArgEnter $ArgEnter -ValueSep $ValueSep
        }
    }
    else {
        $Value = [string]$Value
        if ($Value -match '\s') {
            $CurArg = $ArgEnter + $Name + $ValueSep + '"' + $Value + '"'
        }
        else {
            $CurArg = $ArgEnter + $Name + $ValueSep + $Value
        }
    }

    if (-not [string]::IsNullOrEmpty($CurArg)) {
        $ArgStr = $ArgStr + $ArgSep + $CurArg
    }
    $ArgStr    
} 

function Test-PgDir($Path, [switch]$CreateIfNotExist) {
    if ($Path -eq $null) {Return}
    $TestRes = Test-Path -Path $Path
    if (-not $TestRes -and $CreateIfNotExist) {
        $Item = New-Item -Path $Path -ItemType Directory
        $TestRes = Test-Path -Path $Item.FullName
    }
    $TestRes
}

function Add-PgPath($Path, $AddPath, $Sep = '\') {
    
    if ([String]::IsNullOrEmpty($AddPath)) {return $path}
    if ([String]::IsNullOrEmpty($Path)) {return $AddPath}

    if ($AddPath -is [System.Array]) {
        foreach ($AddPathItem in $AddPath) {
            $Path = Add-PgPath -Path $Path -AddPath $AddPathItem -Sep $Sep
        }
    }
    else {
        if ($Path.EndsWith($Sep)) {
            $Path = $Path.Substring(0, $Path.Length - 1)
        }

        if ($AddPath.StartsWith($Sep)) {
            $AddPath = $AddPath.Substring(1, $Path.Length - 1)
        }
        $Path = $Path + $Sep + $AddPath    
    }

    $Path
}

function Add-PgString($Str, $Add, $Sep = '') {
    if ([String]::IsNullOrEmpty($Str)) {return $Add}
    elseif ([String]::IsNullOrEmpty($Add)) {return $Str}
    else {return $Str + $Sep + $Add}
} 
