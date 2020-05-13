Import-Module common-module

# Version 2.5

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
        bin = $Bin;
        pgdata = $PgData;
        DbName = $DbName;
        Host = $Host;
        Port = $Port;
        UserName = $UserName;
        NoPassword = $NoPassword;
        Password = $Password;
        StatusInterval = $StatusInterval;
        Verbose = $Verbose
    }
}

function Get-PgDatabases($Conn) {

    $FieldSep = ';'

    $Command = 'select oid, datname from pg_database'
    $Return = Invoke-PgSql -Conn $Conn -Command $Command -NoAlign -TuplesOnly -FieldSep $FieldSep
    if (-not $Return.OK) {
       return @()
    }

    $Databases = @()
    foreach ($OutLine in $Return.Out) {
        $LineValues = ([string]$OutLine).Split($FieldSep)
        $Values = @{
            oid = $LineValues[0];
            name = $LineValues[1];
        }
        $Databases += New-Object -TypeName PSCustomObject -Property $Values
    }

    $Databases
}

function Invoke-PgCheckpoint($Conn) {
    Invoke-PgSql -Conn $Conn -Command 'CHECKPOINT'
}

function Invoke-PgReindex() {
    param (
        $Conn,
        $DbName,
        [ValidateSet('Index', 'Table', 'Schema', 'Database')]
        [string]$Object,
        $Name
    )

    if ([string]::IsNullOrEmpty($Name)) {
        $Name = $DbName
    }

    if ([string]::IsNullOrEmpty($Name)) {
        $Name = $Conn.DbName
    }

    if ([string]::IsNullOrEmpty($Object)) {
        $Object = 'Database'
    }

    $Verbose = if ($Conn.Verbose) {'VERBOSE'} else {''}
    $Object = $Object.ToUpper()

    $SqlCmd = 'REINDEX ' + $Verbose + ' ' + $Object + ' ' + (Add-CmnArgValueQuotes -Value $Name)

    Invoke-PgSql -Conn $Conn -DbName $DbName -Command $SqlCmd
}

function Invoke-PgTerminateBackend {
    param (
        $Conn,
        $DbName
    )
    $SqlCmd = "select pg_terminate_backend(st.pid) from pg_stat_activity as st where datname = '" + $DbName + "'"
    Invoke-PgSql -Conn $Conn -Command $SqlCmd
}

function Invoke-PgDumpSimple {
    param (
        $Conn,
        $DbName,
        $File,
        $Compress = 5
    )

    # Never prompt for password
    $Conn.nopassword = $true

    Invoke-PgDump -Conn $Conn -DbName $DbName -File $File -Format custom -JobsNum $JobsNum -Compress $Compress -Encoding 'UTF8'
}

function Invoke-PgRestoreSimple {
    param (
        $Conn,
        $DbName,
        $File
    )

    # Never prompt for password
    $Conn.nopassword = $true

    Invoke-PgRestore -Conn $Conn -DbName $DbName -BackupFile $File -Format custom -IfExists
}

# Low level functions

function Invoke-PgInit {
    param (
        [ValidateSet('trust', 'md5', 'reject', 'password', 'scram-sha-256', 'gss', 'sspi', 'ident', 'peer', 'ldap', 'radius', 'cert')]
        $Auth,
        [ValidateSet('trust', 'md5', 'reject', 'password', 'scram-sha-256', 'gss', 'sspi', 'ident', 'peer', 'ldap', 'radius', 'cert')]
        $AuthHost,
        [ValidateSet('trust', 'md5', 'reject', 'password', 'scram-sha-256', 'gss', 'sspi', 'ident', 'peer', 'ldap', 'radius', 'cert')]
        $AuthLocal,
        $PgData,
        [ValidateSet('UTF8', 'SQL_ASCII', 'WIN866', 'WIN1251', 'KOI8R', 'ISO_8859_5')]
        $Encoding,
        $Locale,
        [switch]$NoLocale,
        $PasswordFile,
        $UserName,
        $WalDir
    )

    $ArgList = [ordered]@{
        auth = $Auth;
        auth_host = $AuthHost;
        auth_local = $AuthLocal;
        pgdata = $PgData;
        encoding = $Encoding;
        locale = $Locale;
        no_locale = $NoLocale;
        pwfile = $PasswordFile;
        username = $UserName;
        waldir = $WalDir;
    }
    $ArgsStr = Get-CmnArgsGNU -ArgList $ArgList

    Invoke-PgExec -Conn $Conn -ExecName 'initdb' -ArgStr $ArgsStr    
}

function Invoke-PgBasebackup {
    param (
        $Conn,
        $BackupPath,
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
        D = $BackupPath;
        F = $Format;
        r = $MaxRate;
        S = $Slot;
        T = $TablespaceMapping;
        X = $XLogMethod;
        z = $GZip;

    }
    $ArgStr = Get-CmnArgsPosix -ArgStr $ArgStr -ArgList $ArgList1

    $ArgList2 = [ordered]@{
        R = $WriteRecoveryConf;
        x = $XLog;
        Z = $Compress;
        c = $Checkpoint;
        l = $Lable;
    }
    $ArgStr = Get-CmnArgsPosix -ArgStr $ArgStr -ArgList $ArgList2

    $ArgList3 = [ordered]@{
        xlogdir = $XLogDir;
    }
    $ArgStr = Get-CmnArgsGNU -ArgStr $ArgStr -ArgList $ArgList3

    $ArgList4 = [ordered]@{
        P = $Progress;
        v = ($Conn.verb -or $Verb);
    }
    $ArgStr = Get-CmnArgsPosix -ArgStr $ArgStr -ArgList $ArgList4

    $ArgList5 = [ordered]@{
        d = $Conn.dbname;
        h = $Conn.host;
        p = $Conn.port;
        s = $Conn.statusInterval;
        U = $Conn.username;
        w = $Conn.nopassword;
    }
    $ArgStr = Get-CmnArgsPosix -ArgStr $ArgStr -ArgList $ArgList5

    $ArgList6 = [ordered]@{
        W = $Conn.password;
    }
    $ArgStr = Get-CmnArgsPosix -ArgStr $ArgStr -ArgList $ArgList6

    Invoke-PgExec -Conn $Conn -ExecName 'pg_basebackup' -ArgStr $ArgStr
}

function Invoke-PgDump {
    param(
        $Conn,
        $DbName,
        [Parameter(HelpMessage="Output file or directory name.")]
        $File,
        [Parameter(HelpMessage="Output file format.")]
        [ValidateSet('custom', 'direcotry', 'tar', 'plain')]
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

    if ([string]::IsNullOrEmpty($DbName) -and (-not [string]::IsNullOrEmpty($Conn.dbname))) {
        $DbName = $Conn.dbname
    }

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
        host = $Conn.Host;
        port = $Conn.Port;
        username = $Conn.UserName;
        no_password = $Conn.NoPassword;
        password = $Conn.Password;
        role = $Role
    }
    $ArgsStr = Get-CmnArgsGNU -ArgList $ArgList

    if (-not [string]::IsNullOrEmpty($DbName)) {
        $ArgsStr = $ArgsStr + ' ' + (Add-CmnArgValueQuotes -Value $DbName)
    }

    Invoke-PgExec -Conn $Conn -ExecName 'pg_dump' -ArgStr $ArgsStr    
}

function Invoke-PgRestore {
    param (
        $Conn,
        $DbName,
        [ValidateSet('custom', 'direcotry', 'tar', 'plain')]
        $Format,
        $BackupFile,
        $OutFile,
        [switch]$List,
        [switch]$DataOnly,
        [switch]$DropObjects,
        [switch]$CreateDb,
        [switch]$ExitOnErr,
        $Index,
        $JobsCount,
        $UseList,
        $Schemas,
        $ExcludeSchemas,
        [switch]$NoOwner,
        $Functions,
        $SchemaOnly,
        $Superuser,
        $Tables,
        $Triggers,
        [switch]$NoPrivileges,
        [switch]$SingleTran,
        [switch]$DisableTriggers,
        [switch]$EnableRowSecurity,
        [switch]$IfExists,
        [switch]$NoDataFailedTables,
        [switch]$NoPublications,
        [switch]$NoSecurityLables,
        [switch]$NoSubscriptions,
        [switch]$NoTablespaces,
        $Sections,
        [switch]$StrictNames,
        [switch]$UseSessionAuth,
        $Role
    )

    if ([string]::IsNullOrEmpty($DbName) -and (-not [string]::IsNullOrEmpty($Conn.dbname))) {
        $DbName = $Conn.dbname
    }

    $ArgList = [ordered]@{
        dbname = $DbName;
        file = $OutFile;
        format = $Format;
        list = $List;
        verbose = $Conn.verbose;
        data_only = $DataOnly;
        clean = $DropObjects;
        create = $CreateDb;
        exit_on_error = $ExitOnErr;
        index = $Index;
        jobs = $JobsCount;
        use_list = $UseList;
        schema = $Schemas;
        exclude_schema = $ExcludeSchemas;
        no_owner = $NoOwner;
        function = $Functions;
        schame_only = $SchemaOnly;
        superuser = $Superuser;
        table = $Tables;
        trigger = $Triggers;
        no_privileges = $NoPrivileges;
        single_transaction = $SingleTran;
        disable_triggers = $DisableTriggers;
        enable_row_security = $EnableRowSecurity;
        if_exists = $IfExists;
        no_data_for_failed_tables = $NoDataFailedTables;
        no_publications = $NoPublications;
        no_security_lables = $NoSecurityLables;
        no_subscriptions = $NoSubscriptions;
        no_tablespaces = $NoTablespaces;
        section = $Sections;
        strict_names = $StrictNames;
        use_set_session_authorization = $UseSessionAuth;
        host = $Conn.Host;
        port = $Conn.Post;
        username = $Conn.UserName;
        no_password = $Conn.NoPassword;
        password = $Conn.Password;
        role = $Role;
    }

    $ArgsStr = Get-CmnArgsGNU -ArgList $ArgList
    $ArgsStr = $ArgsStr + ' ' + (Add-CmnArgValueQuotes -Value $BackupFile)

    Invoke-PgExec -Conn $Conn -ExecName 'pg_restore' -ArgStr $ArgsStr
}

function Invoke-PgSql {
    param (
        $Conn,
        $DbName,
        $UserName,
        $Command,
        $CmdFile,
        [switch]$DbList,
        $Variables,
        [ValidateSet('all', 'errors', 'queries', 'hidden')]
        $Echo,
        $LogFile,
        $OutFile,
        $Quiet,
        [switch]$SingleStepMode,
        [switch]$SingleLineMode,
        [switch]$NoAlign,
        $FieldSep,
        [switch]$Html,
        $PSet,
        $RecordSep,
        [switch]$TuplesOnly,
        $TableAttr,
        $FieldSepZero,
        $RecordSepZero
    )

    if (-not [string]::IsNullOrEmpty($Command)) {
        if ($Command.Contains("`n")) {
            $Command = $Command.Replace("`n", ' ')
        }
        if ($Command.Contains("`r")) {
            $Command = $Command.Replace("`r", ' ')
        }
        if ($Command.Contains('"')) {
            $Command = $Command.Replace('"', '\""')
        }
    }

    $ArgList = [ordered]@{
        command = $Command;
        file = $CmdFile;
        set = $Variables;
        list = $DbList;
        echo_all = ($Echo -eq 'all');
        echo_errors = ($Echo -eq 'errors') -or ('errors' -in $Echo);
        echo_queries = ($Echo -eq 'queries') -or ('queries' -in $Echo);
        echo_hidden = ($Echo -eq 'hidden') -or ('hidden' -in $Echo);
        log_file = $LogFile;
        output = $OutFile;
        quiet = $Quiet;
        single_step = $SingleStepMode;
        single_line = $SingleLineMode;
        no_align = $NoAlign;
        field_separator = $FieldSep;
        html = $Html;
        pset = $PSet;
        record_separator = $RecordSep;
        tuples_only = $TuplesOnly;
        table_attr = $TableAttr;
        field_separator_zero = $FieldSepZero;
        record_separator_zero = $RecordSepZero;
        host = $Conn.host;
        port = $Conn.port;
        username = $Conn.username;
        no_password = $Conn.nopassword;
        password = $Conn.password;
    }

    $ArgsStr = Get-CmnArgsGNU -ArgList $ArgList

    if ([string]::IsNullOrEmpty($DbName) -and (-not [string]::IsNullOrEmpty($Conn.dbname))) {
        $DbName = $Conn.dbname
    }

    if (-not [string]::IsNullOrEmpty($DbName)) {
        $ArgsStr = $ArgsStr + ' ' + (Add-CmnArgValueQuotes -Value $DbName)
        if (-not [string]::IsNullOrEmpty($UserName)) {
            $ArgsStr = $ArgsStr + ' ' + (Add-CmnArgValueQuotes -Value $UserName)
        }
    }

    Invoke-PgExec -Conn $Conn -ExecName 'psql' -ArgStr $ArgsStr
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

    $ArgStr = Get-CmnArgsGNU -ArgList $ArgList1 -ArgStr $ArgStr

    $ArgList2 = [ordered]@{
        N = $ServiceName;
        P = $ServicePwd;
        U = $ServiceUsr;
        S = $ServiceStartType;
        e = $EventSource;
    }

    $ArgStr = Get-CmnArgsPosix -ArgList $ArgList2 -ArgStr $ArgStr

    $StartProcess = ($Command -in @('start', 'restart'))

    Invoke-PgExec -Conn $Conn -ExecName 'pg_ctl' -ArgStr $ArgStr -StartProcess:$StartProcess
}

function Invoke-PgExec($Conn, $ExecName, $ArgStr, [switch]$StartProcess) {
    $FilePath = Add-CmnPath -Path (Get-PgBin -Conn $Conn) -AddPath $ExecName 
    $InvokeError = $null
    $InvokeOut = $null
    $StartTime = Get-Date
    if ($StartProcess) {
        $Process = Start-Process -FilePath $FilePath -ArgumentList $ArgStr -NoNewWindow  -ErrorVariable InvokeError -OutVariable InvokeOut -PassThru
        $OK = ($InvokeError.Count -eq 0) -and ($Process.ExitCode -in @($null, 0))
    }
    else {
        $ExprCommand = $FilePath + ' ' + $ArgStr
        Invoke-Expression $ExprCommand -ErrorVariable InvokeError -OutVariable InvokeOut
        $OK = ($InvokeError.Count -eq 0)
    }
    $EndTime = Get-Date
    $TimeSpan = New-TimeSpan -Start $StartTime -End $EndTime
    @{OK = $OK; Error = $InvokeError; Out = $InvokeOut; Start = $StartTime; End = $EndTime; TimeSpan = $TimeSpan}
}

function Get-PgBin($Conn) {
    $Conn.bin
}
