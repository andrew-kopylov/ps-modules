# PostgreSQL: version 1.1

function Get-PgConn {
    param (
        $Bin,
        $DbName,
        $Host,
        $Port,
        $UserName,
        $NoPassword,
        $Password,
        $StatusInterval,
        [switch]$Verb
    )
    [ordered]@{
        dbname = $DbName;
        host = $Host;
        port = $Post;
        username = $UserName;
        nopassword = $NoPassword;
        password = $Password;
        statusInterval = $StatusInterval;
        verbose = $Verb
    }
}

function Invoke-PgBasebackup {
    param (
        $Conn,
        [Parameter(Mandatory=$true)]
        $PgData,
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

    $ArgsStr = ''

    $ArgsList1 = [ordered]@{
        D = $PgData;
        F = $Format;
        r = $MaxRate;
        S = $Slot;
        T = $TablespaceMapping;
        X = $XLogMethod;
        z = $GZip;

    }
    $ArgsStr = Get-PgArgs -ArgsStr $ArgsStr -ArgsList $ArgsList1

    $ArgsList2 = [ordered]@{
        R = $WriteRecoveryConf;
        x = $XLog;
        Z = $Compress;
        c = $Checkpoint;
        l = $Lable;

    }
    $ArgsStr = Get-PgArgs -ArgsStr $ArgsStr -ArgsList $ArgsList2
    $ArgsStr = Add-PgArg  -ArgsStr $ArgsStr -Name 'xlogdir' -ArgEnter '--' -ValueSep '='

    $ArgsList3 = [ordered]@{
        P = $Progress;
        v = ($Conn.verb -or $Verb);
    }
    $ArgsStr = Get-PgArgs -ArgsStr $ArgsStr -ArgsList $ArgsList3

    $ArgsList4 = [ordered]@{
        d = $Conn.dbname;
        h = $Conn.host;
        p = $Conn.port;
        s = $Conn.statusInterval;
        U = $Conn.username;
        w = $Conn.nopassword;
    }
    $ArgsStr = Get-PgArgs -ArgsStr $ArgsStr -ArgsList $ArgsList4

    $ArgsList5 = [ordered]@{
        W = $Conn.password;
    }
    $ArgsStr = Get-PgArgs -ArgsStr $ArgsStr -ArgsList $ArgsList5

    $FilePath = Add-PgPath -Path (Get-PgBin -Conn $Conn) -AddPath 'pg_basebackup' 

    $InvokeError = @()

    $Result = Invoke-Expression ($FilePath + ' ' + $ArgsStr) -ErrorVariable InvokeError

    @{Result = $Result; Error = $InvokeError[0]}
}

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

function Get-PgDatabases() {


    




}

function Invoke-PgReindex($DbName, $TabName) {

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

function Get-PgArgs($ArgsList, $ArgsStr = '', $ArgSep = ' ', $ArgEnter = '-', $ValueSep = ' ') {
    foreach ($ArgKey in $ArgsList.Keys) {
        $ArgsStr = Add-PgArg -ArgsStr $ArgsStr -Name $ArgKey -Value ($ArgsList.$ArgKey) -ArgSep $ArgSep -ArgEnter $ArgEnter -ValueSep $ValueSep
   }
    $ArgsStr
}

function Add-PgArg($ArgsStr, $Name, $Value, $DefaultValue,  $ArgSep = ' ', $ArgEnter = '-', $ValueSep = ' ') {
    
    if ($Value -eq $null) {$Value = $DefaultValue}
    if ($Value -eq $null) {return $ArgsStr}

    $CurArg = ''
    if ($Value -is [bool] -or $Value -is [switch]) {
        if ($Value) {
            $CurArg = $ArgEnter + $Name
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

    ($ArgsStr + $ArgSep + $CurArg)
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
