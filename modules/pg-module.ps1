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

function Get-PgDatabases() {


    




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

# ---------------------------------------------------------------------
# LOGGING
# ---------------------------------------------------------------------

# Return log parameters
function Get-PgLog($Dir, $Name, $OutHost) {
    # Log directory, Log file base name, Out host - bool, log to Out-Host
    @{Dir = $Dir; Name = $Name; OutHost = $OutHost}
}

function Out-PgLog($Log, $LogMark, $LogText, $OutHost, [switch]$InvokeThrow) {

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
    $OutLogText = Get-PgLogText -LogName $LogName -LogMark $LogMark -LogText $LogText

    $OutLogText | Out-File -FilePath $LogFile -Append

    if (($OutHost -eq $true) -or ((-not $OutHost -eq $false) -and $Log.OutHost -eq $true)) {
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

# ---------------------------------------------------------------------
# AUXILIARY FUNC
# ---------------------------------------------------------------------

function Get-PgPathDirectory($Path) {
    $Info = [System.IO.DirectoryInfo]::new($Path)
    $Info.Parent.FullName
}

function Get-PgPathBaseName($Path) {
    $Info = [System.IO.DirectoryInfo]::new($Path)
    $Info.BaseName
}

function Get-PgPSArgs($ArgsArray) {

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
    
    if ($Path.EndsWith($Sep)) {
        $Path = $Path.Substring(0, $Path.Length - 1)
    }

    if ($AddPath.StartsWith($Sep)) {
        $AddPath = $AddPath.Substring(1, $Path.Length - 1)
    }

    $Path + $Sep + $AddPath    
}

function Add-PgString($Str, $Add, $Sep = '') {
    if ([String]::IsNullOrEmpty($Str)) {return $Add}
    elseif ([String]::IsNullOrEmpty($Add)) {return $Str}
    else {return $Str + $Sep + $Add}
} 
