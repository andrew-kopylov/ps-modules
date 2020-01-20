Import-Module pg-module -Force

$ScriptItem = Get-Item -Path $PSCommandPath

#postgresql.conf parameters:
#wal_level = replica
#archive_mode = on
#archive_command = 'powershell -f d:\\pgdata\\archive-wal.ps1 -p %p [-a d:\\pgdata\\archive-wal -c zip]'
#archive_timeout = 60

#$args += '-p'
#$args += 'pg_wal\00000001000000010000005D'
#$args += '-a'
#$args += 'D:\pgdata\archive-wal'
#$args += '-d'
#$args += 'd:\pgdata\10.9'
#$args += '-c'
#$args += 'zip'

$HArgs = Get-PgPSArgs -ArgsArray $args

#$HArgs = @{
#    p = 'pg_wal\00000001000000010000005D';
#    a = 'D:\pgdata\archive';
#    d = 'D:\pgdata\10.9'
#    c = 'zip'
#}

$ScriptConfigFile = Add-PgPath -Path $ScriptItem.DirectoryName -AddPath config, ($ScriptItem.BaseName + '.json')
$ScriptConfig = Get-Content -Path $ScriptConfigFile | ConvertFrom-Json

if ([String]::IsNullOrEmpty($HArgs.a)) {
    $HArgs.a = $ScriptConfig.archive
}

if ([String]::IsNullOrEmpty($HArgs.p)) {
    throw 'Expected wal-file relative path parameter "p": "PowerShell -f archive-wal.ps1 -p walfile -d archivedir"'
}

if ([String]::IsNullOrEmpty($HArgs.a)) {
    throw 'Expected archive directory path parameter "d": "PowerShell -f archive-wal.ps1 -p walfile -d archivedir"'
}

# Relative wal-file path from data dir
$RelativeWalFileName = $HArgs.p

# Archive directory for wal-files
$ArchiveDir = $HArgs.a

# Init LOG
if (-not [String]::IsNullOrEmpty($HArgs.l)) {
    $LogDir = $HArgs.l
}
elseif (-not [String]::IsNullOrEmpty($ScriptConfig.log)) {
    $LogDir = $ScriptConfig.log
}
else {
    $LogDir = Add-PgPath -Path $ScriptItem.DirectoryName -AddPath logs
}
$Log = Get-PgLog -Dir $LogDir -Name 'archive-wal'

# Data dir
if (-not [String]::IsNullOrEmpty($HArgs.d)) {
    $DataDir = $HArgs.d
}
if (-not [String]::IsNullOrEmpty($ScriptConfig.pgdata)) {
    $DataDir = $ScriptConfig.pgdata
}
else {
    # Location where was started script (data)
    $DataDir = (Get-Location).ToString()
}

if (-not [String]::IsNullOrEmpty($HArgs.c)) {
    $CompressZip = ($HArgs.c -like 'zip')
    $Compress7z = ($HArgs.c -like '7z')
}
elseif ($ScriptConfig.compress -and -not [String]::IsNullOrEmpty($ScriptConfig.compressFormat)) {
    $CompressZip = ($ScriptConfig.compressFormat -like 'zip')
    $Compress7z = ($ScriptConfig.compressFormat -like '7z')
}

if ($Compress7z) {
    Import-Module 7z-module -Force
}

# Source and destination WAL-file
$SourceWalFile = Get-Item -Path (Add-PgPath -Path $DataDir -AddPath $RelativeWalFileName)
$DestWalDir = Add-PgPath -Path $ArchiveDir -AddPath (Get-PgPathBaseName -Path $DataDir), $RelativeWalFileName
$DestWalDir = Get-PgPathParent -Path $DestWalDir

$WalFileBaseNameNew = 'walbackup-' + (Get-Date).ToString('yyyyMMdd-HHmmss.') + $SourceWalFile.Name
$DestWalFilePath = Add-PgPath -Path $DestWalDir -AddPath $WalFileBaseNameNew

# Test|create destination WAL-directory
$TestResult = Test-PgDir -Path $DestWalDir -CreateIfNotExist
if (-not $TestResult) {
    $ErrText = 'WAL-archive directory doesn''t exist: ' + $DestWalDir + '; data directory ' + $DataDir
    Out-PgLog -Log $Log -Mark 'Error' -Text $ErrText -InvokeThrow
}

if (-not (Test-Path -Path $SourceWalFile.FullName)) {
    $ErrText = 'Archived WAL-file doesn''t exist: ' + $SourceWalFile.FullName
    Out-PgLog -Log $Log -Mark 'Error' -Text $ErrText -InvokeThrow
}

# Check WAL-file existance.
if (Test-Path -Path $DestWalFilePath) {
    $ErrText = 'Archived WAL-file copy already exists: ' + $DestWalFilePath
    Out-PgLog -Log $Log -Mark 'Error' -Text $ErrText -InvokeThrow
}

# Copy WAL-file
Out-PgLog -Log $Log -Mark 'Begin' -Text ('wal-file ' + $SourceWalFile.FullName + ' to ' + $DestWalFilePath)
Copy-Item -Path $SourceWalFile.FullName -Destination $DestWalFilePath -Force

# Check wal copy.
if (Test-Path -Path $DestWalFilePath) {
    Out-PgLog -Log $Log -Mark 'Copy' -Text ('wal-file copied successfully ' + $SourceWalFile.FullName)
}
else {
    $ErrText = 'WAL-file doesn''t exists after coping: ' + $SourceWalFile.FullName + ' to ' + $DestWalFilePath
    Out-PgLog -Log $Log -Mark 'Error' -Text $ErrText -InvokeThrow
}


# Compress wal
if ($CompressZIP -or $Compress7z) {

    $DestWalFile = Get-Item -Path $DestWalFilePath
    
    if ($CompressZip) {
        $CompressDest = Add-PgPath -Path ($DestWalFile.DirectoryName) -AddPath ($DestWalFile.Name + '.zip')
        Compress-Archive -Path $DestWalFile -DestinationPath $CompressDest -CompressionLevel Optimal
    }
    elseif ($Compress7z) {
        $CompressDest = Add-PgPath -Path ($DestWalFile.DirectoryName) -AddPath ($DestWalFile.Name + '.7z')
        $CompressResult = Compress-7zArchive -Path $DestWalFile -DestinationPath $CompressDest -CompressionLevel Optimal
    }

    if (Test-Path -Path $CompressDest) {
        Remove-Item -Path $DestWalFile
        Out-PgLog -Log $Log -Mark 'Compress' -Text ('Success to ' + $CompressDest)
    } 
    else {
        Out-PgLog -Log $Log -Mark 'Compress' -Text ('Error ' + $DestWalFile) -InvokeThrow
    }
}

Out-PgLog -Log $Log -Mark 'End' -Text 'OK'
